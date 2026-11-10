import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zelo_mobile/core/data/zelo_repository.dart';
import 'package:zelo_mobile/core/database/local_store.dart';
import 'package:zelo_mobile/core/domain/app_failure.dart';
import 'package:zelo_mobile/features/contacts/data/contact_photo_store.dart';
import 'package:zelo_mobile/features/contacts/domain/contact_photo.dart';

class _Cloud extends ContactPhotoCloud {
  final images = <String, Uint8List>{};
  final removed = <String>[];
  int downloads = 0;
  bool offline = false;
  @override
  Future<void> upload(String path, Uint8List bytes) async {
    if (offline) throw StateError('offline');
    images[path] = bytes;
  }

  @override
  Future<Uint8List?> download(String path) async {
    downloads++;
    return images[path];
  }

  @override
  Future<void> delete(String path) async {
    images.remove(path);
    removed.add(path);
  }

  @override
  Future<void> deleteAccount(String uid) async {
    images.removeWhere((key, value) => key.startsWith('users/$uid/'));
  }
}

void main() {
  sqfliteFfiInit();
  late LocalStore store;
  late ZeloRepository repository;
  late _Cloud cloud;
  late ContactPhotoStore photos;
  final image = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  setUp(() async {
    store = LocalStore(
      await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: LocalStore.createSchema,
        ),
      ),
    );
    repository = ZeloRepository(store, 'owner-a');
    cloud = _Cloud();
    photos = ContactPhotoStore(repository, cloud: cloud);
  });
  tearDown(() => store.close());

  test('photo table upgrade preserves existing contacts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'zelo-photo-migration-',
    );
    final path = '${directory.path}/old.db';
    final old = LocalStore(
      await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await LocalStore.createSchema(db, version);
            await db.execute('DROP TABLE contact_photos');
          },
        ),
      ),
    );
    await ZeloRepository(
      old,
      'owner-a',
    ).saveContact(name: 'Ana', phone: '+5511999999999', email: '');
    await old.close();
    final upgraded = LocalStore(
      await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onUpgrade: LocalStore.upgradeSchema,
        ),
      ),
    );
    try {
      expect(
        (await ZeloRepository(upgraded, 'owner-a').contacts()).single.name,
        'Ana',
      );
      expect(await upgraded.db.query('contact_photos'), isEmpty);
    } finally {
      await upgraded.close();
      await File(path).delete();
      await directory.delete();
    }
  });

  test(
    'legacy cached photos are queued for Firestore even when old uploads were confirmed',
    () async {
      await repository.saveContact(
        name: 'Ana',
        phone: '+5511999999999',
        email: '',
        photoBytes: image,
      );
      final contact = (await repository.contacts()).single;
      final legacy =
          'users/${repository.uid}/contact_photos/${contact.id}/12345678-1234-1234-1234-123456789abc.png';
      final row = (await repository.rows('contacts')).single;
      await store.db.update(
        'records',
        {'payload': jsonEncode(LocalStore.decode(row)..['photoPath'] = legacy)},
        where: 'user_id=? AND id=?',
        whereArgs: [repository.uid, contact.id],
      );
      await store.db.update(
        'contact_photos',
        {'storage_path': legacy, 'uploaded': 1},
        where: 'user_id=?',
        whereArgs: [repository.uid],
      );
      await store.db.delete(
        'outbox',
        where: 'user_id=?',
        whereArgs: [repository.uid],
      );
      await LocalStore.upgradeSchema(store.db, 2, 3);
      expect((await store.db.query('contact_photos')).single['uploaded'], 0);
      expect((await store.db.query('outbox')).single['entity_id'], contact.id);
      expect(
        ContactPhoto.canonicalPath(legacy),
        ContactPhoto.path(
          repository.uid,
          contact.id,
          '12345678-1234-1234-1234-123456789abc',
        ),
      );
      await photos.prepare(await repository.rows('contacts'));
      expect(cloud.images[legacy], image);
    },
  );

  test(
    'contact and photo save atomically and remain available without network',
    () async {
      await repository.saveContact(
        name: 'Ana',
        phone: '+5511999999999',
        email: '',
        photoBytes: image,
      );
      final contact = (await repository.contacts()).single;
      expect(
        ContactPhoto.validPath(repository.uid, contact.id, contact.photoPath!),
        isTrue,
      );
      expect(await photos.read(contact.id, contact.photoPath!), image);
      expect(cloud.downloads, 0);
      cloud.offline = true;
      await expectLater(
        photos.prepare(await repository.rows('contacts')),
        throwsStateError,
      );
      expect((await store.db.query('contact_photos')).single['uploaded'], 0);
      expect(await photos.read(contact.id, contact.photoPath!), image);
      cloud.offline = false;
      await photos.prepare(await repository.rows('contacts'));
      expect(cloud.images[contact.photoPath], image);
      expect((await store.db.query('contact_photos')).single['uploaded'], 1);
    },
  );

  test(
    'name changes and reordering preserve photos; removal waits for remote confirmation',
    () async {
      await repository.saveContact(
        name: 'Ana',
        phone: '+5511999999999',
        email: '',
        photoBytes: image,
      );
      final contact = (await repository.contacts()).single;
      await photos.prepare(await repository.rows('contacts'));
      await repository.saveContact(
        id: contact.id,
        name: 'Ana Silva',
        phone: '+5511999999999',
        email: '',
      );
      await repository.reorderContacts([contact.id]);
      expect((await repository.contacts()).single.photoPath, contact.photoPath);
      await repository.saveContact(
        id: contact.id,
        name: 'Ana Silva',
        phone: '+5511999999999',
        email: '',
        removePhoto: true,
      );
      expect((await repository.contacts()).single.photoPath, isNull);
      await photos.cleanup({contact.photoPath!});
      expect(cloud.removed, isEmpty);
      await photos.cleanup({});
      expect(cloud.removed, [contact.photoPath]);
      expect(await store.db.query('contact_photos'), isEmpty);
    },
  );

  test(
    'replacement and contact deletion remove references without losing old cleanup paths',
    () async {
      await repository.saveContact(
        name: 'Ana',
        phone: '+5511999999999',
        email: '',
        photoBytes: image,
      );
      final first = (await repository.contacts()).single;
      await photos.prepare(await repository.rows('contacts'));
      await repository.saveContact(
        id: first.id,
        name: 'Ana',
        phone: '+5511999999999',
        email: '',
        photoBytes: image,
      );
      final second = (await repository.contacts()).single;
      expect(second.photoPath, isNot(first.photoPath));
      await photos.prepare(await repository.rows('contacts'));
      await photos.cleanup({second.photoPath!});
      expect(cloud.removed, [first.photoPath]);
      await repository.deleteContact(first.id);
      final deleted = LocalStore.decode(
        (await repository.rows('contacts', deleted: true)).single,
      );
      expect(deleted.containsKey('photoPath'), isFalse);
      await photos.cleanup({});
      expect(cloud.images, isEmpty);
    },
  );

  test(
    'failed contact validation does not leave photos and rejects foreign paths',
    () async {
      await expectLater(
        repository.saveContact(
          name: 'A',
          phone: '',
          email: '',
          photoBytes: image,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(await store.db.query('contact_photos'), isEmpty);
      await expectLater(
        repository.saveContact(
          name: 'Ana',
          phone: '+5511999999999',
          email: '',
          photoBytes: Uint8List(9),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        await photos.read(
          'a',
          ContactPhoto.path(
            'other-owner',
            'a',
            '12345678-1234-1234-1234-123456789abc',
          ),
        ),
        isNull,
      );
      expect(cloud.downloads, 0);
    },
  );

  test(
    'remote avatars cache after first private download and remain isolated by account',
    () async {
      await repository.saveContact(
        name: 'Ana',
        phone: '+5511999999999',
        email: '',
      );
      final contact = (await repository.contacts()).single;
      final path = ContactPhoto.path(
        repository.uid,
        contact.id,
        '12345678-1234-1234-1234-123456789abc',
      );
      final row = (await repository.rows('contacts')).single;
      await store.db.update(
        'records',
        {'payload': jsonEncode(LocalStore.decode(row)..['photoPath'] = path)},
        where: 'user_id=? AND id=?',
        whereArgs: [repository.uid, contact.id],
      );
      cloud.images[path] = image;
      expect(await photos.read(contact.id, path), image);
      expect(await photos.read(contact.id, path), image);
      expect(cloud.downloads, 1);
      expect(
        await ContactPhotoStore(
          ZeloRepository(store, 'other-owner'),
          cloud: cloud,
        ).read(contact.id, path),
        isNull,
      );
    },
  );
}
