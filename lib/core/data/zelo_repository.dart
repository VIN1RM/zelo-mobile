import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../features/contacts/domain/emergency_contact.dart';
import '../../features/contacts/domain/contact_photo.dart';
import '../../features/emergency/domain/incident.dart';
import '../../features/monitoring/domain/monitoring_session.dart';
import '../database/local_store.dart';
import '../domain/app_failure.dart';

class ZeloRepository {
  ZeloRepository(this.store, this.uid);
  final LocalStore store;
  final String uid;
  static const uuid = Uuid();
  int get now => DateTime.now().toUtc().millisecondsSinceEpoch;

  Future<List<Map<String, Object?>>> rows(
    String type, {
    bool deleted = false,
  }) => store.db.query(
    'records',
    where: 'user_id=? AND entity_type=?${deleted ? '' : ' AND is_deleted=0'}',
    whereArgs: [uid, type],
    orderBy: 'updated_at DESC',
  );
  Future<List<EmergencyContact>> contacts() async =>
      (await rows('contacts'))
          .map(
            (row) => EmergencyContact.fromJson(
              LocalStore.decode(row)..['revision'] = row['revision'],
            ),
          )
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
  Future<List<MonitoringSession>> sessions() async => (await rows(
    'sessions',
  )).map((row) => MonitoringSession.fromJson(LocalStore.decode(row))).toList();
  Future<List<Incident>> incidents() async => (await rows(
    'incidents',
  )).map((row) => Incident.fromJson(LocalStore.decode(row))).toList();
  Future<MonitoringSession?> activeSession() async {
    final all = await sessions();
    for (final session in all) {
      if (session.operational) return session;
    }
    return null;
  }

  Future<void> put(
    Transaction tx,
    String type,
    Map<String, dynamic> data, {
    bool deleted = false,
    int? slot,
  }) async {
    final id = data['id'] as String;
    if (deleted) {
      // Keep the typed identity/revision needed to reject stale writes, while
      // removing content that must not survive record deletion or retention.
      data = Map<String, dynamic>.from(data)..remove('notes');
      if (data.containsKey('location')) data['location'] = null;
      if (type == 'contacts') {
        final photoPath = data.remove('photoPath');
        if (photoPath is String && ContactPhoto.validPath(uid, id, photoPath)) {
          await tx.insert('contact_photos', {
            'user_id': uid,
            'contact_id': id,
            'storage_path': photoPath,
            'uploaded': 1,
            'created_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        data.addAll({
          'name': 'Registro excluído',
          'phone': null,
          // Reserved non-deliverable domain; satisfies the typed SQL contract.
          'email': 'deleted@zelo.invalid',
        });
      }
    }
    final old = await tx.query(
      'records',
      where: 'user_id=? AND entity_type=? AND id=?',
      whereArgs: [uid, type, id],
    );
    if (old.isNotEmpty && old.first['is_deleted'] == 1 && !deleted) {
      throw const AppFailure(
        'Registro excluído não pode ser restaurado por uma atualização antiga.',
      );
    }
    final revision = old.isEmpty ? 1 : (old.first['revision'] as int) + 1;
    final values = <String, Object?>{
      'user_id': uid,
      'entity_type': type,
      'id': id,
      'payload': jsonEncode(data),
      'revision': revision,
      'base_revision': old.isEmpty ? 0 : old.first['base_revision'],
      'is_deleted': deleted ? 1 : 0,
      'updated_at': now,
      'priority': type == 'contacts' ? data['priority'] : null,
      'slot': type == 'contacts' ? (slot ?? old.firstOrNull?['slot']) : null,
      'operational':
          type == 'sessions' &&
              data['local'] != false &&
              !deleted &&
              const ['PREPARING', 'ACTIVE', 'LIMITED'].contains(data['status'])
          ? 1
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
    if (old.isEmpty) {
      await tx.insert('records', values);
    } else {
      await tx.update(
        'records',
        values,
        where: 'user_id=? AND entity_type=? AND id=?',
        whereArgs: [uid, type, id],
      );
    }
    await tx.insert('outbox', {
      'user_id': uid,
      'entity_type': type,
      'entity_id': id,
      'revision': revision,
      'status': 'PENDING',
      'attempts': 0,
      'next_attempt_at': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveContact({
    String? id,
    int? expectedRevision,
    required String name,
    required String phone,
    required String email,
    Uint8List? photoBytes,
    bool removePhoto = false,
  }) async {
    if (photoBytes != null &&
        (removePhoto || !ContactPhoto.validBytes(photoBytes))) {
      throw const AppFailure('Escolha uma miniatura PNG de até 64 KB.');
    }
    final normalizedPhone = EmergencyContact.normalizePhone(phone);
    final normalizedEmail = email.trim().isEmpty
        ? null
        : email.trim().toLowerCase();
    EmergencyContact.validate(name, normalizedPhone, normalizedEmail);
    await store.db.transaction((tx) async {
      final all = await tx.query(
        'records',
        where: "user_id=? AND entity_type='contacts' AND is_deleted=0",
        whereArgs: [uid],
      );
      final existing = all.where((row) => row['id'] == id).firstOrNull;
      if (expectedRevision != null &&
          existing?['revision'] != expectedRevision) {
        throw const AppFailure(
          'O contato mudou desde que você abriu o formulário. Reabra para revisar antes de salvar.',
        );
      }
      if (id != null && existing == null) {
        throw const AppFailure('Contato não encontrado.');
      }
      if (existing == null && all.length >= 3) {
        throw const AppFailure('Você pode cadastrar até três contatos.');
      }
      for (final row in all.where((row) => row['id'] != id)) {
        final item = LocalStore.decode(row);
        if ((normalizedPhone != null && item['phone'] == normalizedPhone) ||
            (normalizedEmail != null && item['email'] == normalizedEmail)) {
          throw const AppFailure('Esse canal já pertence a outro contato.');
        }
      }
      final slot =
          existing?['slot'] as int? ??
          [
            1,
            2,
            3,
          ].firstWhere((slot) => !all.any((row) => row['slot'] == slot));
      final contactId = id ?? uuid.v4();
      final oldPhoto = existing == null
          ? null
          : LocalStore.decode(existing)['photoPath'] as String?;
      var photoPath = removePhoto ? null : oldPhoto;
      if (photoBytes != null) {
        photoPath = ContactPhoto.path(uid, contactId, uuid.v4());
        await tx.insert('contact_photos', {
          'user_id': uid,
          'contact_id': contactId,
          'storage_path': photoPath,
          'bytes': photoBytes,
          'uploaded': 0,
          'created_at': now,
        });
      }
      if (oldPhoto != null &&
          oldPhoto != photoPath &&
          ContactPhoto.validPath(uid, contactId, oldPhoto)) {
        await tx.insert('contact_photos', {
          'user_id': uid,
          'contact_id': contactId,
          'storage_path': oldPhoto,
          'uploaded': 1,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await put(
        tx,
        'contacts',
        EmergencyContact(
          id: contactId,
          name: name.trim(),
          priority: existing?['priority'] as int? ?? all.length + 1,
          phone: normalizedPhone,
          email: normalizedEmail,
          photoPath: photoPath,
        ).toJson(),
        slot: slot,
      );
    });
  }

  Future<void> deleteContact(String id) async {
    await store.db.transaction((tx) async {
      final all = await tx.query(
        'records',
        where: "user_id=? AND entity_type='contacts' AND is_deleted=0",
        whereArgs: [uid],
        orderBy: 'priority',
      );
      if (!all.any((row) => row['id'] == id)) {
        throw const AppFailure('Contato não encontrado.');
      }
      final active = await tx.query(
        'records',
        where: "user_id=? AND entity_type='sessions' AND operational=1",
        whereArgs: [uid],
      );
      if (all.length == 1 && active.isNotEmpty) {
        throw const AppFailure(
          'Encerre a proteção antes de excluir o último contato.',
        );
      }
      final row = all.firstWhere((row) => row['id'] == id);
      await put(tx, 'contacts', LocalStore.decode(row), deleted: true);
      var priority = 1;
      for (final remaining in all.where((row) => row['id'] != id)) {
        final data = LocalStore.decode(remaining)..['priority'] = priority++;
        await put(tx, 'contacts', data);
      }
    });
  }

  Future<void> reorderContacts(List<String> ids) => store.db.transaction((
    tx,
  ) async {
    final all = await tx.query(
      'records',
      where: "user_id=? AND entity_type='contacts' AND is_deleted=0",
      whereArgs: [uid],
    );
    if (ids.length != all.length ||
        ids.toSet().length != ids.length ||
        !all.every((row) => ids.contains(row['id']))) {
      throw const AppFailure('Ordem de contatos inválida.');
    }
    // Deferred uniqueness is not supported by SQLite partial indexes. Hide the
    // rows inside this transaction while assigning their final unique priorities.
    await tx.update(
      'records',
      {'is_deleted': 1},
      where: "user_id=? AND entity_type='contacts' AND is_deleted=0",
      whereArgs: [uid],
    );
    for (var i = 0; i < ids.length; i++) {
      final row = all.firstWhere((row) => row['id'] == ids[i]);
      await tx.update(
        'records',
        {
          'priority': i + 1,
          'payload': jsonEncode(LocalStore.decode(row)..['priority'] = i + 1),
          'is_deleted': 0,
        },
        where: "user_id=? AND entity_type='contacts' AND id=?",
        whereArgs: [uid, ids[i]],
      );
      await put(tx, 'contacts', LocalStore.decode(row)..['priority'] = i + 1);
    }
  });

  Future<void> saveSession(MonitoringSession session) =>
      store.db.transaction((tx) => put(tx, 'sessions', session.toJson()));
  Future<void> preserveSession(String id, bool value) =>
      store.db.transaction((tx) async {
        final data = await requireRecord(tx, 'sessions', id);
        data['preserved'] = value;
        await put(tx, 'sessions', data);
      });
  Future<void> saveIncident(Incident incident) =>
      store.db.transaction((tx) => put(tx, 'incidents', incident.toJson()));

  Future<Map<String, dynamic>> requireRecord(
    Transaction tx,
    String type,
    String id,
  ) async {
    final rows = await tx.query(
      'records',
      where: 'user_id=? AND entity_type=? AND id=? AND is_deleted=0',
      whereArgs: [uid, type, id],
    );
    if (rows.isEmpty) {
      throw const AppFailure('Registro não encontrado nesta conta.');
    }
    return LocalStore.decode(rows.single);
  }

  Future<void> updateIncident(
    String id, {
    String? condition,
    String? notes,
    bool? preserved,
  }) => store.db.transaction((tx) async {
    final data = await requireRecord(tx, 'incidents', id);
    if (data['outcome'] == 'PENDING' &&
        (condition != null || preserved != null)) {
      throw const AppFailure(
        'Responda ao alerta antes de alterar a condição ou a preservação.',
      );
    }
    if (condition != null &&
        !const ['SAFE', 'NEEDS_HELP'].contains(condition)) {
      throw const AppFailure('Condição inválida.');
    }
    if (condition != null && data['condition'] != condition) {
      await put(tx, 'updates', {
        'id': uuid.v4(),
        'incidentId': id,
        'previousCondition': data['condition'],
        'condition': condition,
        'createdAt': now,
      });
      data['condition'] = condition;
    }
    if (notes != null) {
      if (notes.length > 4000) {
        throw const AppFailure('Use até 4.000 caracteres nas observações.');
      }
      data['notes'] = notes;
    }
    if (preserved != null) data['preserved'] = preserved;
    await put(tx, 'incidents', data);
  });

  Future<void> deleteRecord(String type, String id) => store.db.transaction((
    tx,
  ) async {
    final data = await requireRecord(tx, type, id);
    if (type == 'sessions') {
      if ((await tx.query(
        'records',
        where:
            "user_id=? AND entity_type='sessions' AND id=? AND operational=1",
        whereArgs: [uid, id],
      )).isNotEmpty) {
        throw const AppFailure('Encerre a sessão antes de excluir.');
      }
      final children = await tx.query(
        'records',
        where:
            "user_id=? AND entity_type='incidents' AND parent_id=? AND is_deleted=0",
        whereArgs: [uid, id],
      );
      if (children.isNotEmpty) {
        throw const AppFailure(
          'A sessão possui ocorrências. Exclua as ocorrências primeiro.',
        );
      }
    }
    if (type == 'incidents' && data['outcome'] == 'PENDING') {
      throw const AppFailure('Resolva o alerta antes de excluir.');
    }
    if (type == 'incidents') {
      final updates = await tx.query(
        'records',
        where:
            "user_id=? AND entity_type='updates' AND parent_id=? AND is_deleted=0",
        whereArgs: [uid, id],
      );
      for (final row in updates) {
        await put(tx, 'updates', LocalStore.decode(row), deleted: true);
      }
    }
    await put(tx, type, data, deleted: true);
  });

  Future<String?> preference(String name) async =>
      (await store.db.query(
            'preferences',
            where: 'user_id=? AND name=?',
            whereArgs: [uid, name],
          )).firstOrNull?['value']
          as String?;
  Future<void> setPreference(String name, String value) => store.db
      .insert('preferences', {
        'user_id': uid,
        'name': name,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<int> pendingCount() async => (await store.db.query(
    'outbox',
    where: 'user_id=?',
    whereArgs: [uid],
  )).length;

  Future<void> retain() async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 90));
    for (final incident in await incidents()) {
      if (!incident.preserved &&
          !incident.pending &&
          incident.occurredAt.isBefore(cutoff)) {
        await deleteRecord('incidents', incident.id);
      }
    }
    final remaining = await incidents();
    for (final session in await sessions()) {
      if (!session.operational &&
          !session.preserved &&
          session.startedAt.isBefore(cutoff) &&
          !remaining.any((i) => i.sessionId == session.id)) {
        await deleteRecord('sessions', session.id);
      }
    }
  }
}
