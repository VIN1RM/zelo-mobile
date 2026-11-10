import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

import '../../../core/data/zelo_repository.dart';
import '../../../core/domain/app_failure.dart';
import '../../auth/domain/auth_validation.dart';
import '../../history/data/attachment_store.dart';
import '../../monitoring/data/monitoring_gateway.dart';
import '../../settings/data/reminder_gateway.dart';

class AccountService {
  AccountService(this.repository, this.auth, this.firestore);
  final ZeloRepository repository;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  User get user {
    final user = auth.currentUser;
    if (user == null || user.uid != repository.uid) {
      throw const AppFailure('A sessão mudou. Entre novamente.');
    }
    return user;
  }

  Future<void> rename(String name) async {
    final error = AuthValidation.name(name);
    if (error != null) throw AppFailure(error);
    await user.updateDisplayName(name.trim());
    await repository.store.db.transaction(
      (tx) => repository.put(tx, 'profiles', {
        'id': repository.uid,
        'name': name.trim(),
        'email': user.email ?? '',
      }),
    );
  }

  Future<void> signOut() async {
    if (await repository.activeSession() != null ||
        (await repository.incidents()).any((i) => i.pending)) {
      throw const AppFailure(
        'Encerre a proteção e resolva o alerta antes de sair.',
      );
    }
    await ReminderGateway().activate(null);
    await auth.signOut();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final page = await collection
          .limit(100)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      if (page.docs.isEmpty) return;
      final batch = firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(const Duration(seconds: 15));
    }
  }

  Future<void> delete(String password) async {
    if (await repository.activeSession() != null ||
        (await repository.incidents()).any((i) => i.pending)) {
      throw const AppFailure(
        'Encerre a proteção e resolva os alertas antes de excluir a conta.',
      );
    }
    final current = user;
    await current.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: current.email!, password: password),
    );
    await repository.setPreference('deleting', 'true');
    await ReminderGateway().remove(repository.uid);
    final fence = firestore.collection('account_deletions').doc(repository.uid);
    await firestore.runTransaction((tx) async {
      final snapshot = await tx.get(fence);
      if (!snapshot.exists) {
        tx.set(fence, {
          'userId': repository.uid,
          'phase': 'REQUESTED',
          'createdAt': repository.now,
        });
      }
    });
    final root = firestore.collection('users').doc(repository.uid);
    // Deletion is resumable: repeat from the beginning, always query the server,
    // remove children first and never delete Auth before confirming metadata.
    while (true) {
      final page = await root
          .collection('incidents')
          .limit(50)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      if (page.docs.isEmpty) break;
      for (final incident in page.docs) {
        await _deleteCollection(incident.reference.collection('updates'));
        await incident.reference.delete().timeout(const Duration(seconds: 15));
      }
    }
    await _deleteCollection(root.collection('emergency_contacts'));
    await _deleteCollection(root.collection('monitoring_sessions'));
    await root.delete().timeout(const Duration(seconds: 15));
    if ((await root.get(const GetOptions(source: Source.server))).exists) {
      throw const AppFailure('A exclusão remota ainda não foi confirmada.');
    }
    for (final collection in [
      'incidents',
      'emergency_contacts',
      'monitoring_sessions',
    ]) {
      if ((await root
              .collection(collection)
              .limit(1)
              .get(const GetOptions(source: Source.server)))
          .docs
          .isNotEmpty) {
        throw const AppFailure(
          'A exclusão remota está incompleta. Tente novamente.',
        );
      }
    }
    await repository.setPreference('deleting', 'remoteConfirmed');
    await fence
        .update({'phase': 'DATA_REMOVED'})
        .timeout(const Duration(seconds: 15));
    // Local deletion remains UID-scoped even if Auth emits sign-out immediately.
    final attachments = AttachmentStore(repository);
    for (final row in await repository.store.db.query(
      'attachments',
      where: 'user_id=?',
      whereArgs: [repository.uid],
    )) {
      await attachments.remove(row);
    }
    final rootDirectory = await getApplicationSupportDirectory();
    final photoDirectory = Directory(
      '${rootDirectory.path}/photos/${base64Url.encode(utf8.encode(repository.uid))}',
    );
    if (await photoDirectory.exists()) {
      for (final file in photoDirectory.listSync().whereType<File>()) {
        await file.delete();
      }
    }
    await const MonitoringGateway().clear(repository.uid);
    await repository.store.db.transaction((tx) async {
      for (final table in [
        'outbox',
        'records',
        'attachments',
        'share_attempts',
        'native_receipts',
        'diagnostics',
      ]) {
        await tx.delete(table, where: 'user_id=?', whereArgs: [repository.uid]);
      }
      await tx.delete(
        'preferences',
        where: 'user_id=? AND name!=?',
        whereArgs: [repository.uid, 'deleting'],
      );
    });
    await current.delete();
    await repository.store.db.delete(
      'preferences',
      where: 'user_id=?',
      whereArgs: [repository.uid],
    );
  }
}
