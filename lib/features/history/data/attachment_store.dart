import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/data/zelo_repository.dart';
import '../../../core/domain/app_failure.dart';

class AttachmentStore {
  AttachmentStore(this.repository);
  final ZeloRepository repository;
  final cipher = AesGcm.with256bits();
  Future<SecretKey> _key() async {
    const storage = FlutterSecureStorage();
    var value = await storage.read(key: 'zelo.photos.key.v1');
    if (value == null) {
      value = base64Url.encode(
        List.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await storage.write(key: 'zelo.photos.key.v1', value: value);
    }
    return SecretKey(base64Url.decode(value));
  }

  Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    return Directory(
      '${root.path}/photos/${base64Url.encode(utf8.encode(repository.uid))}',
    ).create(recursive: true);
  }

  Future<void> add(String incidentId, ImageSource source) async {
    if ((await list(incidentId)).length >= 10) {
      throw const AppFailure('Você pode anexar até dez fotos por ocorrência.');
    }
    if (!(await repository.incidents()).any((i) => i.id == incidentId)) {
      throw const AppFailure('Ocorrência não encontrada.');
    }
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw const AppFailure('Escolha uma foto de até 10 MB.');
    }
    final id = ZeloRepository.uuid.v4();
    final box = await cipher.encrypt(
      bytes,
      secretKey: await _key(),
      aad: utf8.encode('${repository.uid}:$incidentId:$id'),
    );
    final file = File('${(await _directory()).path}/$id.enc');
    await file.writeAsBytes([
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ], flush: true);
    try {
      await repository.store.db.insert('attachments', {
        'user_id': repository.uid,
        'incident_id': incidentId,
        'id': id,
        'path': file.path,
        'created_at': repository.now,
      });
    } catch (_) {
      await file.delete();
      rethrow;
    }
    final cache = await getTemporaryDirectory();
    if (File(image.path).absolute.path.startsWith(
      '${cache.absolute.path}${Platform.pathSeparator}',
    )) {
      try {
        await File(image.path).delete();
      } catch (_) {}
    }
  }

  Future<List<Map<String, Object?>>> list(String incidentId) =>
      repository.store.db.query(
        'attachments',
        where: 'user_id=? AND incident_id=?',
        whereArgs: [repository.uid, incidentId],
      );
  Future<Uint8List> read(Map<String, Object?> attachment) async {
    if (attachment['user_id'] != repository.uid) {
      throw const AppFailure('Foto de outra conta.');
    }
    final file = File(attachment['path'] as String);
    if (!file.absolute.path.startsWith(
      '${(await _directory()).absolute.path}${Platform.pathSeparator}',
    )) {
      throw const AppFailure('Caminho de foto inválido.');
    }
    final bytes = await file.readAsBytes();
    final box = SecretBox(
      bytes.sublist(28),
      nonce: bytes.sublist(0, 12),
      mac: Mac(bytes.sublist(12, 28)),
    );
    return Uint8List.fromList(
      await cipher.decrypt(
        box,
        secretKey: await _key(),
        aad: utf8.encode(
          '${repository.uid}:${attachment['incident_id']}:${attachment['id']}',
        ),
      ),
    );
  }

  Future<void> remove(Map<String, Object?> row) async {
    if (row['user_id'] != repository.uid) {
      throw const AppFailure('Foto de outra conta.');
    }
    final file = File(row['path'] as String);
    if (!file.absolute.path.startsWith(
      '${(await _directory()).absolute.path}${Platform.pathSeparator}',
    )) {
      throw const AppFailure('Caminho inválido.');
    }
    if (await file.exists()) await file.delete();
    await repository.store.db.delete(
      'attachments',
      where: 'user_id=? AND id=?',
      whereArgs: [repository.uid, row['id']],
    );
  }

  Future<void> cleanup() async {
    final active = (await repository.incidents()).map((i) => i.id).toSet();
    final all = await repository.store.db.query(
      'attachments',
      where: 'user_id=?',
      whereArgs: [repository.uid],
    );
    for (final row in all) {
      if (!active.contains(row['incident_id'])) await remove(row);
    }
  }
}
