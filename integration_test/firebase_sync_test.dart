import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zelo_mobile/core/data/zelo_repository.dart';
import 'package:zelo_mobile/core/database/local_store.dart';
import 'package:zelo_mobile/core/sync/sync_engine.dart';
import 'package:zelo_mobile/features/emergency/domain/incident.dart';
import 'package:zelo_mobile/features/profile/data/account_service.dart';
import 'package:zelo_mobile/features/monitoring/domain/monitoring_session.dart';

Future<Map<String, dynamic>> request(
  String path, {
  Map<String, dynamic>? data,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('http://10.0.2.2:9099$path');
    final request = data == null
        ? await client.getUrl(uri)
        : await client.postUrl(uri);
    if (data != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
    }
    final response = await request.close();
    final body =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw StateError('Auth emulator HTTP ${response.statusCode}');
    }
    return body;
  } finally {
    client.close(force: true);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'offline-first sync, retries, conflicts and account deletion against local emulators',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('ZELO — Firestore/Auth emulados')),
        ),
      );
      final firebase = await Firebase.initializeApp(
        name: 'sync-integration-${DateTime.now().microsecondsSinceEpoch}',
        options: const FirebaseOptions(
          apiKey: 'fake-api-key',
          appId: '1:1234567890:android:abcdef',
          messagingSenderId: '1234567890',
          projectId: 'demo-zelo',
        ),
      );
      final auth = FirebaseAuth.instanceFor(app: firebase);
      final firestore = FirebaseFirestore.instanceFor(app: firebase);
      firestore.settings = const Settings(persistenceEnabled: false);
      await auth.useAuthEmulator('10.0.2.2', 9099);
      firestore.useFirestoreEmulator('10.0.2.2', 8080);
      final email =
          'integration-${DateTime.now().microsecondsSinceEpoch}@zelo.example.test';
      const password = 'IntegrationPass1!';
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await credential.user!.sendEmailVerification();
      final codes = await request('/emulator/v1/projects/demo-zelo/oobCodes');
      final verification = (codes['oobCodes'] as List)
          .cast<Map<String, dynamic>>()
          .lastWhere((code) => code['email'] == email);
      await request(
        '/identitytoolkit.googleapis.com/v1/accounts:update?key=fake-api-key',
        data: {'oobCode': verification['oobCode']},
      );
      await credential.user!.reload();
      await auth.currentUser!.getIdToken(true);
      expect(auth.currentUser!.emailVerified, isTrue);
      final store = await LocalStore.open();
      final repository = ZeloRepository(store, uid);
      final sync = SyncEngine(repository, firestore);
      try {
        await store.db.transaction(
          (tx) => repository.put(tx, 'profiles', {
            'id': uid,
            'name': 'Rider de teste',
            'email': email,
          }),
        );
        for (var i = 1; i <= 3; i++) {
          await repository.saveContact(
            name: 'Contato $i',
            phone: '+551199999000$i',
            email: '',
          );
        }
        await sync.synchronize();
        expect(await repository.pendingCount(), 0);
        final contacts = await repository.contacts();
        await repository.reorderContacts(
          contacts.reversed.map((c) => c.id).toList(),
        );
        await sync.synchronize();
        expect(await repository.pendingCount(), 0);
        final first = (await repository.contacts()).first;
        await repository.saveContact(
          id: first.id,
          name: 'Nome local',
          phone: first.phone!,
          email: '',
        );
        final local = (await repository.rows(
          'contacts',
        )).firstWhere((r) => r['id'] == first.id);
        final ref = firestore
            .collection('users')
            .doc(uid)
            .collection('emergency_contacts')
            .doc('${local['slot']}');
        final remote = (await ref.get(
          const GetOptions(source: Source.server),
        )).data()!;
        await ref.set({
          ...remote,
          'revision': (remote['revision'] as int) + 1,
          'data': {
            ...Map<String, dynamic>.from(remote['data'] as Map),
            'name': 'Nome remoto',
          },
        });
        final report = await sync.synchronize();
        expect(
          report.conflicts,
          1,
          reason:
              '${report.message}; ${await repository.store.db.query('outbox', where: 'user_id=?', whereArgs: [uid])}',
        );
        expect((await repository.contacts()).first.name, 'Nome local');
        await sync.acceptRemote('contacts', first.id);
        expect((await repository.contacts()).first.name, 'Nome remoto');

        final session = MonitoringSession(
          id: ZeloRepository.uuid.v4(),
          startedAt: DateTime.now().toUtc(),
          status: 'COMPLETED',
          position: PhonePosition.pocket,
        );
        await repository.saveSession(session);
        final incident = Incident(
          id: ZeloRepository.uuid.v4(),
          type: 'MANUAL_SOS',
          sessionId: session.id,
          occurredAt: DateTime.now().toUtc(),
          outcome: 'HELP_REQUESTED',
          condition: 'NEEDS_HELP',
          preserved: true,
        );
        await repository.saveIncident(incident);
        await sync.synchronize();
        expect(await repository.pendingCount(), 0);
        // Simulate losing the local acknowledgement after a successful server write.
        final row = (await repository.rows('incidents')).single;
        await store.db.transaction((tx) async {
          await tx.update(
            'records',
            {'base_revision': 0},
            where: "user_id=? AND entity_type='incidents' AND id=?",
            whereArgs: [uid, incident.id],
          );
          await tx.insert('outbox', {
            'user_id': uid,
            'entity_type': 'incidents',
            'entity_id': incident.id,
            'revision': row['revision'],
          });
        });
        await sync.synchronize();
        expect(await repository.pendingCount(), 0);
        await repository.deleteRecord('incidents', incident.id);
        await sync.synchronize();
        expect(await repository.incidents(), isEmpty);
        expect(await repository.pendingCount(), 0);
        final incidentRef = firestore
            .collection('users')
            .doc(uid)
            .collection('incidents')
            .doc(incident.id);
        final tombstone = (await incidentRef.get(
          const GetOptions(source: Source.server),
        )).data()!;
        await expectLater(
          incidentRef.set({
            ...tombstone,
            'deleted': false,
            'revision': (tombstone['revision'] as int) + 1,
          }),
          throwsA(isA<FirebaseException>()),
        );
        await AccountService(repository, auth, firestore).delete(password);
        expect(auth.currentUser, isNull);
        expect(await repository.rows('contacts', deleted: true), isEmpty);
      } finally {
        await store.close();
        await firebase.delete();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
