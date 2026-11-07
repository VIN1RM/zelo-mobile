import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class LocalStore {
  LocalStore(this.db);
  final Database db;

  static Future<LocalStore> open() async {
    const storage = FlutterSecureStorage();
    var password = await storage.read(key: 'zelo.database.key.v1');
    if (password == null) {
      password = base64Url.encode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await storage.write(key: 'zelo.database.key.v1', value: password);
    }
    final directory = await getApplicationSupportDirectory();
    final db = await openDatabase(
      '${directory.path}/zelo.db',
      password: password,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: createSchema,
    );
    return LocalStore(db);
  }

  /// Common SQLite contracts allow the schema/transactions to be tested on FFI.
  static Future<void> createSchema(Database db, int version) async {
    await db.execute(r'''CREATE TABLE records (
      user_id TEXT NOT NULL, entity_type TEXT NOT NULL CHECK(entity_type IN ('profiles','contacts','sessions','incidents','updates')),
      id TEXT NOT NULL, payload TEXT NOT NULL, revision INTEGER NOT NULL CHECK(revision>0),
      base_revision INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0,1)),
      updated_at INTEGER NOT NULL, priority INTEGER, slot INTEGER, operational INTEGER NOT NULL DEFAULT 0 CHECK(operational IN (0,1)),
      parent_type TEXT, parent_id TEXT,
      PRIMARY KEY(user_id,entity_type,id),
      FOREIGN KEY(user_id,parent_type,parent_id) REFERENCES records(user_id,entity_type,id) DEFERRABLE INITIALLY DEFERRED,
      CHECK((parent_type IS NULL) = (parent_id IS NULL)),
      CHECK(json_valid(payload)),
      CHECK(json_extract(payload,'$.id')=id),
      CHECK(entity_type != 'contacts' OR (json_extract(payload,'$.phone') IS NOT NULL OR json_extract(payload,'$.email') IS NOT NULL)),
      CHECK(entity_type != 'contacts' OR (priority BETWEEN 1 AND 3 AND slot BETWEEN 1 AND 3))
    )''');
    await db.execute(
      "CREATE UNIQUE INDEX contact_priority ON records(user_id,priority) WHERE entity_type='contacts' AND is_deleted=0",
    );
    await db.execute(
      "CREATE UNIQUE INDEX contact_slot ON records(user_id,slot) WHERE entity_type='contacts' AND is_deleted=0",
    );
    await db.execute(
      "CREATE UNIQUE INDEX active_session ON records(user_id) WHERE entity_type='sessions' AND operational=1 AND is_deleted=0",
    );
    await db.execute('''CREATE TABLE outbox (
      user_id TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, revision INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','CONFLICT','DENIED')),
      attempts INTEGER NOT NULL DEFAULT 0, next_attempt_at INTEGER NOT NULL DEFAULT 0, error_code TEXT,
      PRIMARY KEY(user_id,entity_type,entity_id),
      FOREIGN KEY(user_id,entity_type,entity_id) REFERENCES records(user_id,entity_type,id) ON DELETE CASCADE
    )''');
    await db.execute(
      'CREATE INDEX pending_sync ON outbox(user_id,status,next_attempt_at)',
    );
    await db.execute(
      'CREATE TABLE preferences (user_id TEXT NOT NULL, name TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(user_id,name))',
    );
    await db.execute(
      'CREATE TABLE attachments (user_id TEXT NOT NULL, incident_id TEXT NOT NULL, id TEXT NOT NULL, path TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY(user_id,id))',
    );
    await db.execute(
      'CREATE TABLE share_attempts (user_id TEXT NOT NULL, incident_id TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(user_id,id))',
    );
    await db.execute(
      'CREATE TABLE native_receipts (user_id TEXT NOT NULL, id TEXT NOT NULL, PRIMARY KEY(user_id,id))',
    );
    await db.execute(
      'CREATE TABLE diagnostics (user_id TEXT NOT NULL, code TEXT NOT NULL, created_at INTEGER NOT NULL)',
    );
  }

  static Map<String, dynamic> decode(Map<String, Object?> row) =>
      jsonDecode(row['payload'] as String) as Map<String, dynamic>;
  Future<void> close() => db.close();
}
