import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart' as cloud;
import 'contact_photo_picker.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/data/zelo_repository.dart';
import '../../../core/database/local_store.dart';
import '../../../core/domain/app_failure.dart';
import '../domain/contact_photo.dart';

abstract class ContactPhotoCloud {
  Future<void> upload(String path, Uint8List bytes);
  Future<Uint8List?> download(String path);
  Future<void> delete(String path);
  Future<void> deleteAccount(String uid);
}

class FirestoreContactPhotoCloud implements ContactPhotoCloud {
  FirestoreContactPhotoCloud({cloud.FirebaseFirestore? firestore})
    : _firestore = firestore;
  final cloud.FirebaseFirestore? _firestore;
  cloud.FirebaseFirestore get firestore =>
      _firestore ?? cloud.FirebaseFirestore.instance;
  cloud.DocumentReference<Map<String, dynamic>> reference(String path) =>
      firestore.doc(ContactPhoto.canonicalPath(path));

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    if (!ContactPhoto.validBytes(bytes)) {
      throw const AppFailure('A miniatura deve ter até 64 KB.');
    }
    final target = reference(path);
    final contactId = target.parent.parent!.id;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = firestore.batch();
    batch.set(target.parent.parent!, {
      'contactId': contactId,
      'updatedAt': now,
    });
    batch.set(target, {
      'contactId': contactId,
      'bytes': cloud.Blob(bytes),
      'contentType': 'image/png',
      'updatedAt': now,
    });
    await batch.commit().timeout(const Duration(seconds: 15));
  }

  @override
  Future<Uint8List?> download(String path) async {
    final snapshot = await reference(path)
        .get(const cloud.GetOptions(source: cloud.Source.server))
        .timeout(const Duration(seconds: 12));
    final value = snapshot.data()?['bytes'];
    return value is cloud.Blob ? value.bytes : null;
  }

  @override
  Future<void> delete(String path) =>
      reference(path).delete().timeout(const Duration(seconds: 12));

  @override
  Future<void> deleteAccount(String uid) async {
    final parents = firestore
        .collection('users')
        .doc(uid)
        .collection('contact_photos');
    while (true) {
      final page = await parents
          .limit(50)
          .get(const cloud.GetOptions(source: cloud.Source.server))
          .timeout(const Duration(seconds: 12));
      if (page.docs.isEmpty) return;
      for (final parent in page.docs) {
        while (true) {
          final versions = await parent.reference
              .collection('versions')
              .limit(100)
              .get(const cloud.GetOptions(source: cloud.Source.server))
              .timeout(const Duration(seconds: 12));
          if (versions.docs.isEmpty) break;
          final batch = firestore.batch();
          for (final version in versions.docs) {
            batch.delete(version.reference);
          }
          await batch.commit().timeout(const Duration(seconds: 15));
        }
        await parent.reference.delete().timeout(const Duration(seconds: 12));
      }
    }
  }
}

class ContactPhotoStore {
  ContactPhotoStore(this.repository, {ContactPhotoCloud? cloud})
    : cloud = cloud ?? FirestoreContactPhotoCloud();
  final ZeloRepository repository;
  final ContactPhotoCloud cloud;

  Future<Uint8List?> read(String contactId, String path) async {
    if (!ContactPhoto.validPath(repository.uid, contactId, path)) return null;
    final cached = await repository.store.db.query(
      'contact_photos',
      where: 'user_id=? AND storage_path=?',
      whereArgs: [repository.uid, path],
    );
    final bytes = cached.firstOrNull?['bytes'] as Uint8List?;
    if (bytes != null) return bytes;
    final downloaded = await cloud.download(path);
    if (downloaded == null || !ContactPhoto.validBytes(downloaded)) return null;
    final retained = await repository.store.db.transaction((tx) async {
      final current = await tx.query(
        'records',
        where: "user_id=? AND entity_type='contacts' AND id=? AND is_deleted=0",
        whereArgs: [repository.uid, contactId],
      );
      final deleting = await tx.query(
        'preferences',
        where: 'user_id=? AND name=?',
        whereArgs: [repository.uid, 'deleting'],
      );
      if (current.isEmpty ||
          LocalStore.decode(current.single)['photoPath'] != path ||
          deleting.isNotEmpty) {
        return false;
      }
      await tx.update(
        'contact_photos',
        {'bytes': downloaded, 'uploaded': 1},
        where: 'user_id=? AND storage_path=? AND bytes IS NULL',
        whereArgs: [repository.uid, path],
      );
      await tx.insert('contact_photos', {
        'user_id': repository.uid,
        'contact_id': contactId,
        'storage_path': path,
        'bytes': downloaded,
        'uploaded': 1,
        'created_at': repository.now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return true;
    });
    return retained ? downloaded : null;
  }

  Future<void> prepare(Iterable<Map<String, Object?>> contacts) async {
    for (final row in contacts) {
      if (row['is_deleted'] == 1) continue;
      final path = LocalStore.decode(row)['photoPath'] as String?;
      if (path == null) continue;
      final id = row['id'] as String;
      if (!ContactPhoto.validPath(repository.uid, id, path)) {
        throw const AppFailure('Referência de foto inválida.');
      }
      final local = await repository.store.db.query(
        'contact_photos',
        where: 'user_id=? AND storage_path=?',
        whereArgs: [repository.uid, path],
      );
      if (local.isEmpty || local.single['uploaded'] == 1) continue;
      var bytes = local.single['bytes'] as Uint8List?;
      if (bytes == null) {
        throw const AppFailure(
          'A foto local não está disponível. Reabra o contato e escolha outra foto.',
        );
      }
      if (!ContactPhoto.validBytes(bytes)) {
        bytes = await ContactPhotoPicker().normalize(bytes);
        await repository.store.db.update(
          'contact_photos',
          {'bytes': bytes},
          where: 'user_id=? AND storage_path=?',
          whereArgs: [repository.uid, path],
        );
      }
      await cloud.upload(path, bytes);
      await repository.store.db.update(
        'contact_photos',
        {'uploaded': 1},
        where: 'user_id=? AND storage_path=?',
        whereArgs: [repository.uid, path],
      );
    }
  }

  Future<void> cleanup(Set<String> remotePaths) async {
    final cached = await repository.store.db.query(
      'contact_photos',
      where: 'user_id=?',
      whereArgs: [repository.uid],
    );
    final active = (await repository.contacts())
        .map((contact) => contact.photoPath)
        .whereType<String>()
        .toSet();
    for (final row in cached) {
      final path = row['storage_path'] as String;
      if (active.contains(path) || remotePaths.contains(path)) continue;
      if (!ContactPhoto.validPath(
        repository.uid,
        row['contact_id'] as String,
        path,
      )) {
        continue;
      }
      await cloud.delete(path);
      await repository.store.db.delete(
        'contact_photos',
        where: 'user_id=? AND storage_path=?',
        whereArgs: [repository.uid, path],
      );
    }
  }
}
