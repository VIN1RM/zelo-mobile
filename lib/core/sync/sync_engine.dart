import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/zelo_repository.dart';
import '../database/local_store.dart';
import '../domain/app_failure.dart';
import 'json_equality.dart';
import '../../features/contacts/domain/emergency_contact.dart';
import '../../features/contacts/data/contact_photo_store.dart';

class SyncReport {
  const SyncReport({
    this.sent = 0,
    this.conflicts = 0,
    this.message = 'Sincronização concluída.',
    this.remoteDataLoaded = false,
  });
  final int sent;
  final int conflicts;
  final String message;
  final bool remoteDataLoaded;
}

class SyncEngine {
  SyncEngine(this.repository, this.firestore, {ContactPhotoCloud? photoCloud})
    : photos = ContactPhotoStore(
        repository,
        cloud: photoCloud ?? FirestoreContactPhotoCloud(firestore: firestore),
      );
  final ZeloRepository repository;
  final FirebaseFirestore firestore;
  final ContactPhotoStore photos;
  bool _running = false;

  Future<T> _transaction<T>(Future<T> Function(Transaction) action) async {
    AppFailure? rejection;
    try {
      return await firestore.runTransaction<T>((transaction) async {
        rejection = null;
        try {
          return await action(transaction);
        } on AppFailure catch (error) {
          // Android can report its abort before FlutterFire forwards the Dart
          // exception. Preserve the domain reason for explicit conflict review.
          rejection = error;
          rethrow;
        }
      });
    } on FirebaseException {
      if (rejection != null) throw rejection!;
      rethrow;
    }
  }

  Future<void> _sendContacts(List<Map<String, Object?>> pending) async {
    final all = await repository.rows('contacts', deleted: true);
    final chosen = <int, Map<String, Object?>>{};
    for (final row in all) {
      final slot = row['slot'] as int;
      if (!pending.any((p) => p['slot'] == slot)) continue;
      if (!chosen.containsKey(slot) || row['is_deleted'] == 0) {
        chosen[slot] = row;
      }
    }
    await photos.prepare(chosen.values);
    await _transaction<void>((transaction) async {
      final snapshots = <int, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final slot in chosen.keys) {
        snapshots[slot] = await transaction.get(
          reference('contacts', '', {}, slot: slot),
        );
      }
      for (final entry in chosen.entries) {
        final row = entry.value;
        final remote = snapshots[entry.key]!.data();
        if (remote != null &&
            remote['id'] == row['id'] &&
            remote['revision'] == row['revision'] &&
            remote['deleted'] == (row['is_deleted'] == 1) &&
            sameJson(remote['data'], LocalStore.decode(row))) {
          continue;
        }
        if (remote != null && remote['id'] != row['id']) {
          if (row['is_deleted'] == 1) continue;
          if (remote['deleted'] != true) {
            throw const AppFailure('CONTACT_GENERATION_CONFLICT');
          }
        } else if (remote != null) {
          if (remote['deleted'] == true && row['is_deleted'] == 0) {
            throw const AppFailure('REMOTE_DELETED');
          }
          if (remote['revision'] != row['base_revision']) {
            throw const AppFailure('CONTACT_REVISION_CONFLICT');
          }
        } else if (row['base_revision'] != 0) {
          throw const AppFailure('CONTACT_MISSING');
        }
        transaction.set(reference('contacts', '', {}, slot: entry.key), {
          'id': row['id'],
          'userId': repository.uid,
          'revision': row['revision'],
          'deleted': row['is_deleted'] == 1,
          'data': LocalStore.decode(row),
          'updatedAt': row['updated_at'],
        });
      }
    });
    await repository.store.db.transaction((tx) async {
      for (final row in pending) {
        final sent = chosen[row['slot']];
        final confirmedRevision = sent != null && sent['id'] == row['id']
            ? sent['revision']
            : row['revision'];
        await tx.update(
          'records',
          {'base_revision': confirmedRevision},
          where: "user_id=? AND entity_type='contacts' AND id=?",
          whereArgs: [repository.uid, row['id']],
        );
        await tx.delete(
          'outbox',
          where:
              "user_id=? AND entity_type='contacts' AND entity_id=? AND revision=?",
          whereArgs: [repository.uid, row['id'], confirmedRevision],
        );
      }
    });
  }

  DocumentReference<Map<String, dynamic>> reference(
    String type,
    String id,
    Map<String, dynamic> data, {
    int? slot,
  }) {
    final user = firestore.collection('users').doc(repository.uid);
    return switch (type) {
      'profiles' => user,
      'contacts' => user.collection('emergency_contacts').doc('$slot'),
      'sessions' => user.collection('monitoring_sessions').doc(id),
      'incidents' => user.collection('incidents').doc(id),
      'updates' =>
        user
            .collection('incidents')
            .doc(data['incidentId'] as String)
            .collection('updates')
            .doc(id),
      _ => throw const AppFailure('Tipo de sincronização inválido.'),
    };
  }

  Future<SyncReport> synchronize({bool pullRemote = true}) async {
    if (_running) {
      return const SyncReport(message: 'Sincronização já está em andamento.');
    }
    _running = true;
    var sent = 0;
    var pulled = false;
    try {
      if (await repository.preference('deleting') != null) {
        return const SyncReport(
          message: 'A exclusão da conta está pendente. Retome em Minha conta.',
        );
      }
      final rows = await repository.store.db.rawQuery(
        '''SELECT r.*,o.attempts FROM records r JOIN outbox o
        ON r.user_id=o.user_id AND r.entity_type=o.entity_type AND r.id=o.entity_id
        WHERE r.user_id=? AND o.status='PENDING' AND o.next_attempt_at<=?
        ORDER BY CASE r.entity_type WHEN 'profiles' THEN 0 WHEN 'contacts' THEN 1 WHEN 'sessions' THEN 2 WHEN 'incidents' THEN 3 ELSE 4 END,r.updated_at''',
        [repository.uid, repository.now],
      );
      final contacts = rows
          .where((row) => row['entity_type'] == 'contacts')
          .toList();
      if (contacts.isNotEmpty) {
        try {
          await _sendContacts(contacts);
          sent += contacts.length;
        } on AppFailure catch (error) {
          for (final row in contacts) {
            await repository.store.db.update(
              'outbox',
              {'status': 'CONFLICT', 'error_code': error.message},
              where: "user_id=? AND entity_type='contacts' AND entity_id=?",
              whereArgs: [repository.uid, row['id']],
            );
          }
        } on FirebaseException catch (error) {
          final denied = const [
            'permission-denied',
            'unauthenticated',
            'failed-precondition',
          ].contains(error.code);
          for (final row in contacts) {
            await repository.store.db.update(
              'outbox',
              {
                'status': denied ? 'DENIED' : 'PENDING',
                'attempts': (row['attempts'] as int) + 1,
                'next_attempt_at': repository.now + 60000,
                'error_code': error.code,
              },
              where: "user_id=? AND entity_type='contacts' AND entity_id=?",
              whereArgs: [repository.uid, row['id']],
            );
          }
          if (!denied) {
            return SyncReport(
              sent: sent,
              message:
                  'Contatos aguardando confirmação remota. Dados locais preservados.',
            );
          }
        }
      }
      for (final row in rows.where((row) => row['entity_type'] != 'contacts')) {
        final type = row['entity_type'] as String;
        final id = row['id'] as String;
        final data = LocalStore.decode(row)
          ..remove('notes')
          ..remove('local');
        final target = reference(type, id, data, slot: row['slot'] as int?);
        try {
          final remoteRevision = await _transaction<int>((transaction) async {
            final snapshot = await transaction.get(target);
            final remote = snapshot.data();
            if (remote != null &&
                remote['id'] == id &&
                remote['revision'] == row['revision'] &&
                remote['deleted'] == (row['is_deleted'] == 1) &&
                sameJson(remote['data'], data)) {
              return row['revision'] as int;
            }
            if (remote != null && remote['id'] != id) {
              if (row['is_deleted'] == 1) {
                return -1; // Old contact generation cannot delete its replacement.
              }
              if (remote['deleted'] != true) throw const AppFailure('CONFLICT');
            } else if (remote != null) {
              if (remote['deleted'] == true && row['is_deleted'] == 0) {
                throw const AppFailure('REMOTE_DELETED');
              }
              if (remote['revision'] != row['base_revision']) {
                throw const AppFailure('CONFLICT');
              }
            } else if (row['base_revision'] != 0) {
              throw const AppFailure('CONFLICT');
            }
            final revision = row['revision'] as int;
            transaction.set(target, {
              'id': id,
              'userId': repository.uid,
              'revision': revision,
              'deleted': row['is_deleted'] == 1,
              'data': data,
              'updatedAt': row['updated_at'],
            });
            return revision;
          });
          await repository.store.db.transaction((tx) async {
            await tx.update(
              'records',
              {
                'base_revision': remoteRevision < 0
                    ? row['revision']
                    : remoteRevision,
              },
              where: 'user_id=? AND entity_type=? AND id=?',
              whereArgs: [repository.uid, type, id],
            );
            await tx.delete(
              'outbox',
              where:
                  'user_id=? AND entity_type=? AND entity_id=? AND revision=?',
              whereArgs: [repository.uid, type, id, row['revision']],
            );
          });
          sent++;
        } on AppFailure catch (error) {
          await repository.store.db.update(
            'outbox',
            {'status': 'CONFLICT', 'error_code': error.message},
            where: 'user_id=? AND entity_type=? AND entity_id=?',
            whereArgs: [repository.uid, type, id],
          );
        } on FirebaseException catch (error) {
          final denied = const [
            'permission-denied',
            'unauthenticated',
            'failed-precondition',
          ].contains(error.code);
          final attempts = (row['attempts'] as int) + 1;
          await repository.store.db.update(
            'outbox',
            {
              'status': denied ? 'DENIED' : 'PENDING',
              'attempts': attempts,
              'error_code': error.code,
              'next_attempt_at':
                  repository.now +
                  min(3600000, 1000 * (1 << min(attempts, 11))),
            },
            where: 'user_id=? AND entity_type=? AND entity_id=?',
            whereArgs: [repository.uid, type, id],
          );
          if (!denied) {
            return SyncReport(
              sent: sent,
              message:
                  'Sem confirmação remota. Dados locais e operações pendentes foram preservados.',
            );
          }
        }
      }
      if (pullRemote && await repository.preference('deleting') == null) {
        await pull();
        pulled = true;
      }
      final photoRows = await repository.store.db.query(
        'contact_photos',
        columns: ['storage_path'],
        where: 'user_id=?',
        whereArgs: [repository.uid],
        limit: 1,
      );
      if (photoRows.isNotEmpty &&
          await repository.preference('deleting') == null) {
        try {
          final remoteContacts = await firestore
              .collection('users')
              .doc(repository.uid)
              .collection('emergency_contacts')
              .get(const GetOptions(source: Source.server));
          await photos.cleanup(
            remoteContacts.docs
                .where((doc) => doc.data()['deleted'] != true)
                .map((doc) => (doc.data()['data'] as Map)['photoPath'])
                .whereType<String>()
                .toSet(),
          );
        } catch (_) {
          return SyncReport(
            sent: sent,
            remoteDataLoaded: pulled,
            message:
                'Dados sincronizados. A limpeza de fotos antigas será tentada novamente.',
          );
        }
      }
      final conflicts = await repository.store.db.query(
        'outbox',
        where: "user_id=? AND status!='PENDING'",
        whereArgs: [repository.uid],
      );
      return SyncReport(
        sent: sent,
        conflicts: conflicts.length,
        remoteDataLoaded: pulled,
        message: conflicts.isEmpty
            ? 'Sincronização confirmada pelo servidor.'
            : 'Há conflitos ou falhas de autorização. Revise as pendências nos ajustes.',
      );
    } on FirebaseException {
      return SyncReport(
        sent: sent,
        message:
            'Servidor indisponível ou sem autorização. Dados locais preservados.',
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _accept(
    String type,
    Map<String, dynamic> remote, {
    int? slot,
    bool replacePending = false,
  }) async {
    if (remote['userId'] != repository.uid ||
        remote['id'] is! String ||
        remote['revision'] is! int ||
        remote['data'] is! Map) {
      throw const AppFailure('Metadados remotos inválidos.');
    }
    final id = remote['id'] as String;
    await repository.store.db.transaction((tx) async {
      final existing = await tx.query(
        'records',
        where: 'user_id=? AND entity_type=? AND id=?',
        whereArgs: [repository.uid, type, id],
      );
      final pending = await tx.query(
        'outbox',
        where: 'user_id=? AND entity_type=? AND entity_id=?',
        whereArgs: [repository.uid, type, id],
      );
      if (existing.firstOrNull?['is_deleted'] == 1 &&
          remote['deleted'] != true) {
        return;
      }
      if (pending.isNotEmpty && remote['deleted'] != true && !replacePending) {
        return;
      }
      if (existing.isNotEmpty &&
          (existing.single['base_revision'] as int) >
              (remote['revision'] as int)) {
        return;
      }
      final data = Map<String, dynamic>.from(remote['data'] as Map)
        ..['id'] = id;
      if (type == 'incidents') {
        data['notes'] = remote['deleted'] == true || existing.isEmpty
            ? ''
            : LocalStore.decode(existing.single)['notes'] ?? '';
      }
      if (type == 'sessions') {
        data['local'] =
            existing.isNotEmpty &&
            LocalStore.decode(existing.single)['local'] != false;
      }
      final values = <String, Object?>{
        'user_id': repository.uid,
        'entity_type': type,
        'id': id,
        'payload': jsonEncode(data),
        'revision': remote['revision'],
        'base_revision': remote['revision'],
        'is_deleted': remote['deleted'] == true ? 1 : 0,
        'updated_at': remote['updatedAt'],
        'slot': slot,
        'priority': type == 'contacts' ? data['priority'] : null,
        'operational':
            type == 'sessions' &&
                data['local'] != false &&
                const [
                  'PREPARING',
                  'ACTIVE',
                  'LIMITED',
                ].contains(data['status'])
            ? (existing.firstOrNull?['operational'] ?? 0)
            : 0,
        'parent_type': type == 'updates'
            ? 'incidents'
            : type == 'incidents' && data['sessionId'] != null
            ? 'sessions'
            : null,
        'parent_id': type == 'updates'
            ? data['incidentId']
            : type == 'incidents'
            ? data['sessionId']
            : null,
      };
      if (remote['deleted'] == true) values['operational'] = 0;
      try {
        if (existing.isEmpty) {
          await tx.insert('records', values);
        } else {
          await tx.update(
            'records',
            values,
            where: 'user_id=? AND entity_type=? AND id=?',
            whereArgs: [repository.uid, type, id],
          );
        }
        if (remote['deleted'] == true || replacePending) {
          await tx.delete(
            'outbox',
            where: 'user_id=? AND entity_type=? AND entity_id=?',
            whereArgs: [repository.uid, type, id],
          );
        }
      } catch (_) {
        // A concurrent slot/priority change must not violate local invariants.
        if (pending.isNotEmpty) {
          await tx.update(
            'outbox',
            {'status': 'CONFLICT', 'error_code': 'REMOTE_INVARIANT'},
            where: 'user_id=? AND entity_type=? AND entity_id=?',
            whereArgs: [repository.uid, type, id],
          );
        }
        rethrow;
      }
    });
  }

  Future<void> _pages(
    CollectionReference<Map<String, dynamic>> collection,
    Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>) accept,
  ) async {
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      Query<Map<String, dynamic>> query = collection
          .orderBy(FieldPath.documentId)
          .limit(100);
      if (last != null) query = query.startAfterDocument(last);
      final page = await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      for (final doc in page.docs) {
        await accept(doc);
      }
      if (page.docs.length < 100) break;
      last = page.docs.last;
    }
  }

  Future<void> pull() async {
    final user = firestore.collection('users').doc(repository.uid);
    final profile = await user
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    if (profile.data() != null) await _accept('profiles', profile.data()!);
    await _pullContacts(user.collection('emergency_contacts'));
    await _pages(
      user.collection('monitoring_sessions'),
      (doc) => _accept('sessions', doc.data()),
    );
    await _pages(user.collection('incidents'), (doc) async {
      await _accept('incidents', doc.data());
      await _pages(
        doc.reference.collection('updates'),
        (update) => _accept('updates', update.data()),
      );
    });
  }

  /// Explicit conflict resolution accepts the current server version, never a
  /// silent last-write-wins overwrite. Tombstones are retained locally.
  Future<void> acceptRemote(String type, String id) async {
    if (type == 'contacts') {
      await _pullContacts(
        firestore
            .collection('users')
            .doc(repository.uid)
            .collection('emergency_contacts'),
        force: true,
      );
      return;
    }
    final row = (await repository.store.db.query(
      'records',
      where: 'user_id=? AND entity_type=? AND id=?',
      whereArgs: [repository.uid, type, id],
    )).single;
    final remote = await reference(
      type,
      id,
      LocalStore.decode(row),
      slot: row['slot'] as int?,
    ).get(const GetOptions(source: Source.server));
    if (remote.data() == null) {
      throw const AppFailure(
        'Registro remoto ausente; mantenha a pendência para revisão.',
      );
    }
    await _accept(
      type,
      remote.data()!,
      slot: row['slot'] as int?,
      replacePending: true,
    );
  }

  Future<void> _pullContacts(
    CollectionReference<Map<String, dynamic>> collection, {
    bool force = false,
  }) async {
    final remote = await collection
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    final pending = await repository.store.db.query(
      'outbox',
      where: "user_id=? AND entity_type='contacts'",
      whereArgs: [repository.uid],
    );
    if (pending.isNotEmpty && !force) {
      for (final doc in remote.docs) {
        if (doc.data()['deleted'] == true) {
          await _accept('contacts', doc.data(), slot: int.parse(doc.id));
        }
      }
      return;
    }
    await repository.store.db.transaction((tx) async {
      if (force) {
        await tx.delete(
          'outbox',
          where: "user_id=? AND entity_type='contacts'",
          whereArgs: [repository.uid],
        );
      }
      final old = await tx.query(
        'records',
        where: "user_id=? AND entity_type='contacts'",
        whereArgs: [repository.uid],
      );
      await tx.update(
        'records',
        {'is_deleted': 1},
        where: "user_id=? AND entity_type='contacts'",
        whereArgs: [repository.uid],
      );
      final received = <String>{};
      for (final doc in remote.docs) {
        final value = doc.data();
        final id = value['id'] as String;
        if (value['userId'] != repository.uid ||
            !const ['1', '2', '3'].contains(doc.id)) {
          throw const AppFailure('Contato remoto inválido.');
        }
        final data = Map<String, dynamic>.from(value['data'] as Map);
        final contact = EmergencyContact.fromJson(data);
        EmergencyContact.validate(contact.name, contact.phone, contact.email);
        if (contact.phone != null) {
          EmergencyContact.normalizePhone(contact.phone!);
        }
        final existing = old.where((row) => row['id'] == id).firstOrNull;
        received.add(id);
        final deleted =
            value['deleted'] == true || existing?['is_deleted'] == 1;
        final row = <String, Object?>{
          'user_id': repository.uid,
          'entity_type': 'contacts',
          'id': id,
          'payload': jsonEncode(data),
          'revision': value['revision'],
          'base_revision': value['revision'],
          'is_deleted': deleted ? 1 : 0,
          'updated_at': value['updatedAt'],
          'slot': int.parse(doc.id),
          'priority': contact.priority,
          'operational': 0,
        };
        if (existing == null) {
          await tx.insert('records', row);
        } else {
          await tx.update(
            'records',
            row,
            where: "user_id=? AND entity_type='contacts' AND id=?",
            whereArgs: [repository.uid, id],
          );
        }
      }
      // Unsynced local creations are retained if the first pull finds no cloud copy.
      for (final row in old.where(
        (row) =>
            !received.contains(row['id']) &&
            row['base_revision'] == 0 &&
            row['is_deleted'] == 0,
      )) {
        await tx.update(
          'records',
          {'is_deleted': 0},
          where: "user_id=? AND entity_type='contacts' AND id=?",
          whereArgs: [repository.uid, row['id']],
        );
      }
    });
  }

  Future<void> confirmRemoteDeletion(String type, String id) async {
    final row = (await repository.rows(
      type,
      deleted: true,
    )).firstWhere((row) => row['id'] == id);
    if (row['is_deleted'] != 1) {
      throw const AppFailure('O registro não está excluído localmente.');
    }
    final remote = await reference(
      type,
      id,
      LocalStore.decode(row),
      slot: row['slot'] as int?,
    ).get(const GetOptions(source: Source.server));
    final value = remote.data();
    await repository.store.db.transaction((tx) async {
      if (value == null || value['id'] != id || value['deleted'] == true) {
        await tx.delete(
          'outbox',
          where: 'user_id=? AND entity_type=? AND entity_id=?',
          whereArgs: [repository.uid, type, id],
        );
        return;
      }
      final revision = value['revision'] as int;
      await tx.update(
        'records',
        {'base_revision': revision, 'revision': revision + 1},
        where: 'user_id=? AND entity_type=? AND id=?',
        whereArgs: [repository.uid, type, id],
      );
      await tx.update(
        'outbox',
        {'revision': revision + 1, 'status': 'PENDING', 'next_attempt_at': 0},
        where: 'user_id=? AND entity_type=? AND entity_id=?',
        whereArgs: [repository.uid, type, id],
      );
    });
  }

  Future<void> resolveConflict(
    String type,
    String id, {
    required bool deleted,
  }) => deleted ? confirmRemoteDeletion(type, id) : acceptRemote(type, id);
}
