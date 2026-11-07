import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import 'package:zelo_mobile/core/database/local_store.dart';
import 'package:zelo_mobile/core/data/zelo_repository.dart';
import 'package:zelo_mobile/core/platform/device_permissions.dart';
import 'package:zelo_mobile/features/monitoring/data/monitoring_gateway.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android encrypted storage and native background countdown',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('ZELO — teste local isolado')),
          ),
        ),
      );
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/cipher-integration-${DateTime.now().microsecondsSinceEpoch}.db';
      final encrypted = await cipher.openDatabase(
        path,
        password: 'integration-only-key',
        version: 1,
        onCreate: (db, version) => db.execute('CREATE TABLE proof(value TEXT)'),
      );
      await encrypted.insert('proof', {'value': 'encrypted-marker'});
      await encrypted.close();
      expect(
        utf8.decode(
          (await File(path).readAsBytes()).take(16).toList(),
          allowMalformed: true,
        ),
        isNot(startsWith('SQLite format')),
      );
      await expectLater(
        cipher.openDatabase(
          path,
          password: 'incorrect-test-key',
          singleInstance: false,
        ),
        throwsA(anything),
      );
      await cipher.deleteDatabase(path);

      final uid = 'integration-${DateTime.now().microsecondsSinceEpoch}';
      final store = await LocalStore.open();
      final repository = ZeloRepository(store, uid);
      const native = MonitoringGateway();
      try {
        await repository.saveContact(
          name: 'Contato de teste',
          phone: '+5511999999999',
          email: '',
        );
        expect((await repository.contacts()).length, 1);
        expect(await repository.pendingCount(), 1);
        expect(
          await DevicePermissions.requestNotifications(),
          isTrue,
          reason: 'Autorize notificações para o ensaio local.',
        );
        await native.start(uid, 'integration-session', 'mount');
        await Future<void>.delayed(const Duration(seconds: 5));
        var snapshot = await native.snapshot(uid);
        expect(snapshot['running'], isTrue);
        expect(snapshot['accelerationSamples'] as int, greaterThan(0));
        expect(snapshot['rotationSamples'] as int, greaterThan(0));
        await MonitoringGateway.channel.invokeMethod<void>('testAlert', {
          'uid': uid,
        });
        snapshot = await native.snapshot(uid);
        expect((snapshot['alert'] as Map)['outcome'], 'PENDING');
        await MonitoringGateway.channel.invokeMethod<void>('testBackground', {
          'uid': uid,
        });
        await Future<void>.delayed(const Duration(seconds: 32));
        snapshot = await native.snapshot(uid);
        expect((snapshot['alert'] as Map)['outcome'], 'TIMED_OUT');
        expect(snapshot['running'], isTrue);
        expect(
          (snapshot['events'] as List)
              .where((e) => (e as Map)['type'] == 'incident')
              .length,
          2,
        );
        await native.stop(uid);
        await Future<void>.delayed(const Duration(seconds: 1));
        snapshot = await native.snapshot(uid);
        expect(snapshot['running'], isFalse);
        expect((snapshot['session'] as Map)['status'], 'COMPLETED');
        final otherUid = '$uid-other';
        final isolated = await native.snapshot(otherUid);
        expect(isolated['alert'], isNull);
        expect(isolated['events'], isEmpty);
        await native.clear(otherUid);
        expect(
          ((await native.snapshot(uid))['alert'] as Map)['outcome'],
          'TIMED_OUT',
        );
        final ids = (snapshot['events'] as List)
            .map((e) => (e as Map)['id'] as String)
            .toList();
        await native.acknowledge(uid, ids);
        expect((await native.snapshot(uid))['events'], isEmpty);
      } finally {
        try {
          await native.stop(uid);
        } catch (_) {}
        await Future<void>.delayed(const Duration(seconds: 1));
        await native.clear(uid);
        await store.db.transaction((tx) async {
          for (final table in [
            'outbox',
            'records',
            'preferences',
            'attachments',
            'share_attempts',
            'native_receipts',
            'diagnostics',
          ]) {
            await tx.delete(table, where: 'user_id=?', whereArgs: [uid]);
          }
        });
        await store.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
