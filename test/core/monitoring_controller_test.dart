import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zelo_mobile/core/application/app_controller.dart';
import 'package:zelo_mobile/core/data/zelo_repository.dart';
import 'package:zelo_mobile/core/database/local_store.dart';
import 'package:zelo_mobile/core/domain/app_failure.dart';
import 'package:zelo_mobile/core/platform/device_permissions.dart';
import 'package:zelo_mobile/features/monitoring/data/monitoring_gateway.dart';

class _Native extends MonitoringGateway {
  int starts = 0;
  @override
  Future<void> start(String uid, String id, String position) async {
    starts++;
    throw const AppFailure('Service unavailable');
  }

  @override
  Future<Map<String, dynamic>> snapshot(String uid) async => {
    'running': false,
    'events': [],
  };
}

class _Controller extends AppController {
  _Controller(this.testRepository, this.testNative);
  final ZeloRepository testRepository;
  final MonitoringGateway testNative;
  @override
  Future<AppSnapshot> build() async {
    repository = testRepository;
    native = testNative;
    return const AppSnapshot();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LocalStore store;
  late ZeloRepository repository;
  late _Native native;
  late ProviderContainer container;
  late AppController controller;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    store = LocalStore(
      await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: LocalStore.createSchema,
        ),
      ),
    );
    repository = ZeloRepository(store, 'owner');
    native = _Native();
    container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _Controller(repository, native),
        ),
      ],
    );
    await container.read(appControllerProvider.future);
    controller = container.read(appControllerProvider.notifier);
  });
  tearDown(() async {
    container.dispose();
    messenger.setMockMethodCallHandler(DevicePermissions.channel, null);
    messenger.setMockMethodCallHandler(MonitoringGateway.channel, null);
    await store.close();
  });
  test('no contact blocks start before contacting Android', () async {
    await expectLater(controller.start(), throwsA(isA<AppFailure>()));
    expect(native.starts, 0);
    expect(await repository.sessions(), isEmpty);
  });
  test(
    'denied notifications prevent creation of a monitoring session',
    () async {
      await repository.saveContact(
        name: 'Contato',
        phone: '+5511999999999',
        email: '',
      );
      messenger.setMockMethodCallHandler(
        DevicePermissions.channel,
        (call) async => false,
      );
      await expectLater(controller.start(), throwsA(isA<AppFailure>()));
      expect(native.starts, 0);
      expect(await repository.sessions(), isEmpty);
    },
  );
  test(
    'failed Android startup records interruption and never active protection',
    () async {
      await repository.saveContact(
        name: 'Contato',
        phone: '+5511999999999',
        email: '',
      );
      messenger.setMockMethodCallHandler(
        DevicePermissions.channel,
        (call) async => true,
      );
      await expectLater(controller.start(), throwsA(isA<AppFailure>()));
      expect(native.starts, 1);
      expect((await repository.sessions()).single.status, 'INTERRUPTED');
      expect(
        container.read(appControllerProvider).requireValue.running,
        isFalse,
      );
    },
  );
  test(
    'manual SOS does not require a contact or a monitoring session',
    () async {
      messenger.setMockMethodCallHandler(
        MonitoringGateway.channel,
        (call) async => null,
      );
      final id = await controller.sos();
      final incident = (await repository.incidents()).single;
      expect(incident.id, id);
      expect(incident.sessionId, isNull);
      expect(incident.type, 'MANUAL_SOS');
      expect(incident.preserved, isTrue);
    },
  );
  test('operations serialize before their first async read', () async {
    final gate = Completer<void>();
    final first = controller.operation(() => gate.future);
    await expectLater(
      controller.operation(() async {}),
      throwsA(isA<AppFailure>()),
    );
    gate.complete();
    await first;
  });
  test('manual SOS has priority over an unrelated pending operation', () async {
    messenger.setMockMethodCallHandler(
      MonitoringGateway.channel,
      (call) async => null,
    );
    final gate = Completer<void>();
    final first = controller.operation(() => gate.future);
    final id = await controller.sos();
    expect(id, isNotEmpty);
    expect(container.read(appControllerProvider).requireValue.busy, isTrue);
    gate.complete();
    await first;
  });
}
