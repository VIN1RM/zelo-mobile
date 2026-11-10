import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zelo_mobile/core/application/app_controller.dart';
import 'package:zelo_mobile/core/data/zelo_repository.dart';
import 'package:zelo_mobile/core/database/local_store.dart';
import 'package:zelo_mobile/core/sync/sync_engine.dart';
import 'package:zelo_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:zelo_mobile/features/monitoring/data/monitoring_gateway.dart';
import '../support/fake_auth_repository.dart';

class _Native extends MonitoringGateway {
  @override
  Future<Map<String, dynamic>> snapshot(String uid) async => {
    'running': false,
    'events': [],
  };
  @override
  Future<void> detach(String uid) async {}
}

class _Sync implements SyncEngine {
  _Sync(this.restore);
  final Future<void> Function() restore;
  @override
  Future<void> pull() => restore();
  @override
  Future<SyncReport> synchronize({bool pullRemote = true}) async =>
      const SyncReport();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LocalStore store;
  late ZeloRepository repository;
  late FakeAuthRepository auth;
  ProviderContainer? container;
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
    repository = ZeloRepository(store, verifiedUser.id);
    auth = FakeAuthRepository(user: verifiedUser);
  });
  tearDown(() async {
    container?.dispose();
    container = null;
    await auth.dispose();
    await store.close();
  });

  Future<ProviderContainer> start(_Sync sync) async {
    final result = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        authUserProvider.overrideWithValue(const AsyncData(verifiedUser)),
        repositoryProvider.overrideWith((ref) async => repository),
        monitoringGatewayProvider.overrideWithValue(_Native()),
        syncEngineProvider.overrideWith((ref, repository) => sync),
      ],
    );
    container = result;
    await result.read(authUserProvider.future);
    return result;
  }

  test('first snapshot waits for restored contacts and user data', () async {
    final ready = Completer<void>();
    final result = await start(
      _Sync(() async {
        await ready.future;
        await repository.saveContact(
          name: 'Ana',
          phone: '+5511999999999',
          email: '',
        );
        await repository.store.db.transaction(
          (tx) => repository.put(tx, 'profiles', {
            'id': repository.uid,
            'name': 'Nome remoto',
            'email': verifiedUser.email,
          }),
        );
      }),
    );
    final initial = result.read(appControllerProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(result.read(appControllerProvider).isLoading, isTrue);
    ready.complete();
    final snapshot = await initial;
    expect(snapshot.contacts.single.name, 'Ana');
    expect(snapshot.remoteDataLoaded, isTrue);
    expect(
      LocalStore.decode((await repository.rows('profiles')).single)['name'],
      'Nome remoto',
    );
  });

  test(
    'failed remote lookup preserves cached contacts without confirming an empty account',
    () async {
      await repository.saveContact(
        name: 'Ana',
        phone: '+5511999999999',
        email: '',
      );
      final result = await start(
        _Sync(() async => throw StateError('offline')),
      );
      final snapshot = await result.read(appControllerProvider.future);
      expect(snapshot.contacts.single.name, 'Ana');
      expect(snapshot.remoteDataLoaded, isFalse);
      expect(snapshot.notice, contains('dados da conta'));
    },
  );
}
