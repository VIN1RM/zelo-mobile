import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/device_permissions.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/contacts/domain/emergency_contact.dart';
import '../../features/emergency/data/location_gateway.dart';
import '../../features/emergency/domain/incident.dart';
import '../../features/history/data/attachment_store.dart';
import '../../features/monitoring/data/monitoring_gateway.dart';
import '../../features/monitoring/domain/monitoring_session.dart';
import '../data/zelo_repository.dart';
import '../database/local_store.dart';
import '../domain/app_failure.dart';
import '../sync/sync_engine.dart';
import '../logging/diagnostic_log.dart';

final localStoreProvider = FutureProvider<LocalStore>((ref) async {
  final store = await LocalStore.open();
  ref.onDispose(() => unawaited(store.close()));
  return store;
}, retry: (retryCount, error) => null);

final activeUidProvider = Provider<String?>(
  (ref) => ref.watch(
    authUserProvider.select(
      (session) => session.asData?.value?.emailVerified == true
          ? session.asData?.value?.id
          : null,
    ),
  ),
);
final repositoryProvider = FutureProvider<ZeloRepository>((ref) async {
  final uid = ref.watch(activeUidProvider);
  if (uid == null) throw const AppFailure('Entre com uma conta verificada.');
  return ZeloRepository(await ref.watch(localStoreProvider.future), uid);
}, retry: (retryCount, error) => null);
final monitoringGatewayProvider = Provider((ref) => const MonitoringGateway());

class AppSnapshot {
  const AppSnapshot({
    this.contacts = const [],
    this.sessions = const [],
    this.incidents = const [],
    this.position = PhonePosition.pocket,
    this.prepared = false,
    this.running = false,
    this.busy = false,
    this.emergencyBusy = false,
    this.pendingSync = 0,
    this.issue,
    this.notice,
    this.alertRemainingSeconds,
  });
  final List<EmergencyContact> contacts;
  final List<MonitoringSession> sessions;
  final List<Incident> incidents;
  final PhonePosition position;
  final bool prepared;
  final bool running;
  final bool busy;
  final bool emergencyBusy;
  final int pendingSync;
  final String? issue;
  final String? notice;
  final int? alertRemainingSeconds;
  MonitoringSession? get session =>
      sessions.where((s) => s.operational).firstOrNull;
  Incident? get alert => incidents.where((i) => i.pending).firstOrNull;
  Incident? get unresolved => incidents
      .where(
        (i) =>
            const ['HELP_REQUESTED', 'TIMED_OUT'].contains(i.outcome) &&
            i.condition != 'SAFE',
      )
      .firstOrNull;
}

final appControllerProvider = AsyncNotifierProvider<AppController, AppSnapshot>(
  AppController.new,
);

class AppController extends AsyncNotifier<AppSnapshot> {
  late ZeloRepository repository;
  late MonitoringGateway native;
  Timer? _timer;
  bool _busy = false;
  bool _criticalBusy = false;
  bool _polling = false;
  bool _running = false;
  String? _issue;
  String? _notice;
  int _ticks = 0;
  DateTime _lastPull = DateTime.now();
  int? _alertRemainingSeconds;
  final Set<String> _locationRequested = {};
  late SyncEngine _syncEngine;

  @override
  Future<AppSnapshot> build() async {
    repository = await ref.watch(repositoryProvider.future);
    native = ref.read(monitoringGatewayProvider);
    _syncEngine = SyncEngine(repository, FirebaseFirestore.instance);
    final owner = repository.uid;
    final bridge = native;
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(bridge.detach(owner).catchError((_) {}));
    });
    await _importNative();
    if (await repository.preference('deleting') == null) {
      final user = ref.read(authUserProvider).asData?.value;
      if (user != null && (await repository.rows('profiles')).isEmpty) {
        await repository.store.db.transaction(
          (tx) => repository.put(tx, 'profiles', {
            'id': user.id,
            'name': user.name,
            'email': user.email,
          }),
        );
      }
      await repository.retain();
    }
    await AttachmentStore(repository).cleanup();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(poll()),
    );
    unawaited(_syncQuietly(pullRemote: true));
    return _load();
  }

  Future<AppSnapshot> _load() async => AppSnapshot(
    contacts: await repository.contacts(),
    sessions: await repository.sessions(),
    incidents: await repository.incidents(),
    position: PhonePosition.values.byName(
      await repository.preference('position') ?? 'pocket',
    ),
    prepared: await repository.preference('prepared') == 'true',
    running: _running,
    busy: _busy,
    emergencyBusy: _criticalBusy,
    pendingSync: await repository.pendingCount(),
    issue: _issue,
    notice: _notice,
    alertRemainingSeconds: _alertRemainingSeconds,
  );
  Future<void> refresh() async {
    final snapshot = await _load();
    if (ref.mounted) state = AsyncData(snapshot);
  }

  Future<T> operation<T>(
    Future<T> Function() action, {
    bool allowDuringDeletion = false,
  }) async {
    if (_busy) throw const AppFailure('Aguarde a operação em andamento.');
    _busy = true;
    try {
      if (!allowDuringDeletion &&
          await repository.preference('deleting') != null) {
        throw const AppFailure(
          'A exclusão da conta está pendente. Retome em Minha conta antes de alterar dados.',
        );
      }
      await refresh();
      return await action();
    } finally {
      _busy = false;
      if (ref.mounted) await refresh();
    }
  }

  Future<void> _importNative() async {
    try {
      final snapshot = await native.snapshot(repository.uid);
      _running = snapshot['running'] == true;
      if (_issue != null) await _log('NATIVE_RECOVERED');
      _alertRemainingSeconds = snapshot['remainingMs'] == null
          ? null
          : ((snapshot['remainingMs'] as int) / 1000).ceil();
      _issue = null;
      final events = (snapshot['events'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final receipts = <String>[];
      await repository.store.db.transaction((tx) async {
        for (final event in events) {
          if (event['userId'] != repository.uid) {
            throw const AppFailure('Evento de outra conta.');
          }
          final id = event['id'] as String;
          if ((await tx.query(
            'native_receipts',
            where: 'user_id=? AND id=?',
            whereArgs: [repository.uid, id],
          )).isEmpty) {
            final type = event['type'] == 'session' ? 'sessions' : 'incidents';
            final data = Map<String, dynamic>.from(event['data'] as Map)
              ..remove('userId');
            final old = await tx.query(
              'records',
              where: 'user_id=? AND entity_type=? AND id=?',
              whereArgs: [repository.uid, type, data['id']],
            );
            final merged = old.isEmpty
                ? data
                : (LocalStore.decode(old.single)..addAll(data));
            if (type == 'sessions') merged['local'] = true;
            // A later native resolution cannot rewrite explicit condition updates.
            if (type == 'incidents' &&
                old.isNotEmpty &&
                LocalStore.decode(old.single)['outcome'] != 'PENDING') {
              merged['condition'] = LocalStore.decode(old.single)['condition'];
              merged['outcome'] = LocalStore.decode(old.single)['outcome'];
            }
            if (old.firstOrNull?['is_deleted'] != 1) {
              await repository.put(
                tx,
                type,
                type == 'incidents'
                    ? Incident.fromJson(merged).toJson()
                    : MonitoringSession.fromJson(merged).toJson(),
              );
            }
            await tx.insert('native_receipts', {
              'user_id': repository.uid,
              'id': id,
            });
          }
          receipts.add(id);
        }
      });
      if (receipts.isNotEmpty) {
        await native.acknowledge(repository.uid, receipts);
      }
      final nativeAlert = snapshot['alert'] as Map?;
      if (nativeAlert != null && nativeAlert['outcome'] != 'PENDING') {
        final deleted = await repository.store.db.query(
          'records',
          where:
              "user_id=? AND entity_type='incidents' AND id=? AND is_deleted=1",
          whereArgs: [repository.uid, nativeAlert['id']],
        );
        if (deleted.isNotEmpty) {
          await MonitoringGateway.channel.invokeMethod<void>('dismiss', {
            'uid': repository.uid,
            'id': nativeAlert['id'],
          });
        }
      }
      for (final incident in await repository.incidents()) {
        if (incident.location == null &&
            !_locationRequested.contains(incident.id)) {
          _locationRequested.add(incident.id);
          if (DateTime.now().toUtc().difference(incident.occurredAt).inSeconds <
              60) {
            unawaited(_captureLocation('incidents', incident.id));
          }
        }
      }
      // PREPARING can remain if Android rejects startup before creating a journal.
      if (!_running) {
        final session = await repository.activeSession();
        if (session != null &&
            DateTime.now().toUtc().difference(session.startedAt).inSeconds >
                8) {
          await repository.saveSession(
            MonitoringSession(
              id: session.id,
              startedAt: session.startedAt,
              endedAt: DateTime.now().toUtc(),
              status: 'INTERRUPTED',
              position: session.position,
              location: session.location,
              preserved: session.preserved,
            ),
          );
        }
      }
    } catch (_) {
      _running = false;
      if (_issue == null) await _log('NATIVE_UNCONFIRMED');
      _issue =
          'Não foi possível confirmar o serviço Android. A proteção não está confirmada.';
    }
  }

  Future<T> criticalOperation<T>(Future<T> Function() action) async {
    if (_criticalBusy) {
      throw const AppFailure('Aguarde a resposta de emergência em andamento.');
    }
    _criticalBusy = true;
    try {
      if (await repository.preference('deleting') != null) {
        throw const AppFailure('A exclusão da conta está em andamento.');
      }
      await refresh();
      return await action();
    } finally {
      _criticalBusy = false;
      if (ref.mounted) await refresh();
    }
  }

  Future<void> poll() async {
    if (_polling || !ref.mounted) return;
    _polling = true;
    try {
      if (await repository.preference('deleting') == null) {
        await _importNative();
      }
      if (ref.mounted) await refresh();
      if (++_ticks % 60 == 0) unawaited(_syncQuietly());
    } catch (_) {
      _issue = 'Não foi possível atualizar os dados locais.';
    } finally {
      _polling = false;
    }
  }

  Future<void> resume() async {
    await poll();
    if (DateTime.now().difference(_lastPull) >= const Duration(minutes: 5)) {
      _lastPull = DateTime.now();
      unawaited(_syncQuietly(pullRemote: true));
    }
  }

  Future<void> _captureLocation(String type, String id) async {
    try {
      final location = await LocationGateway().capture();
      if (location == null || !ref.mounted) return;
      if (await repository.preference('deleting') != null) return;
      await repository.store.db.transaction((tx) async {
        final old = await tx.query(
          'records',
          where: 'user_id=? AND entity_type=? AND id=? AND is_deleted=0',
          whereArgs: [repository.uid, type, id],
        );
        if (old.isNotEmpty) {
          await repository.put(
            tx,
            type,
            LocalStore.decode(old.single)..['location'] = location.toJson(),
          );
        }
      });
      if (ref.mounted) await refresh();
    } catch (_) {
      /* Optional location cannot discard a durable incident. */
    }
  }

  Future<void> _log(String code) async {
    try {
      await DiagnosticLog(repository).record(code);
    } catch (_) {}
  }

  Future<void> prepare() => operation(() async {
    if ((await repository.contacts()).isEmpty) {
      throw const AppFailure('Cadastre pelo menos um contato de emergência.');
    }
    if (!await DevicePermissions.notificationsGranted()) {
      throw const AppFailure('Permita notificações para iniciar a proteção.');
    }
    await repository.setPreference('prepared', 'true');
  });
  Future<void> selectPosition(PhonePosition position) => operation(() async {
    if (_running) await native.changePosition(repository.uid, position.name);
    await repository.setPreference('position', position.name);
    await _importNative();
  });
  Future<void> start() => operation(() async {
    if ((await repository.contacts()).isEmpty) {
      throw const AppFailure('Cadastre pelo menos um contato válido.');
    }
    if (!await DevicePermissions.notificationsGranted()) {
      throw const AppFailure(
        'Permita notificações nos ajustes antes de iniciar.',
      );
    }
    if ((await repository.incidents()).any((i) => i.pending)) {
      throw const AppFailure('Resolva o alerta em andamento.');
    }
    if (await repository.activeSession() != null) {
      throw const AppFailure('Já existe uma sessão local.');
    }
    final position = PhonePosition.values.byName(
      await repository.preference('position') ?? 'pocket',
    );
    final session = MonitoringSession(
      id: ZeloRepository.uuid.v4(),
      startedAt: DateTime.now().toUtc(),
      status: 'PREPARING',
      position: position,
    );
    await repository.saveSession(session);
    try {
      await native.start(repository.uid, session.id, position.name);
      for (var i = 0; i < 15; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await _importNative();
        if (_running) break;
      }
      if (!_running) {
        throw const AppFailure('O Android não confirmou o início do serviço.');
      }
      await _log('MONITORING_STARTED');
      unawaited(_captureLocation('sessions', session.id));
    } catch (_) {
      await repository.saveSession(
        MonitoringSession(
          id: session.id,
          startedAt: session.startedAt,
          endedAt: DateTime.now().toUtc(),
          status: 'INTERRUPTED',
          position: position,
        ),
      );
      rethrow;
    }
  });
  Future<void> stop() => operation(() async {
    await native.stop(repository.uid);
    await _importNative();
    await _log('MONITORING_STOPPED');
  });
  Future<void> resolve(String id, String outcome) =>
      criticalOperation(() async {
        await native.resolve(repository.uid, id, outcome);
        await _importNative();
      });
  Future<String> sos() => criticalOperation(() async {
    final pending = (await repository.incidents())
        .where((i) => i.pending)
        .firstOrNull;
    if (pending != null) {
      await native.resolve(repository.uid, pending.id, 'HELP_REQUESTED');
      await _importNative();
      return pending.id;
    }
    final existing = (await repository.incidents())
        .where(
          (i) =>
              const ['HELP_REQUESTED', 'TIMED_OUT'].contains(i.outcome) &&
              i.condition != 'SAFE',
        )
        .firstOrNull;
    if (existing != null) return existing.id;
    final session = await repository.activeSession();
    final incident = Incident(
      id: ZeloRepository.uuid.v4(),
      type: 'MANUAL_SOS',
      occurredAt: DateTime.now().toUtc(),
      outcome: 'HELP_REQUESTED',
      condition: 'NEEDS_HELP',
      preserved: true,
      sessionId: session?.id,
      position: session?.position.name,
    );
    await repository.saveIncident(incident);
    await MonitoringGateway.channel.invokeMethod<void>('blockEmergency', {
      'uid': repository.uid,
      'incident': jsonEncode(incident.toJson()),
    });
    unawaited(_captureLocation('incidents', incident.id));
    return incident.id;
  });
  Future<void> deleteRecord(String type, String id) => operation(() async {
    await repository.deleteRecord(type, id);
    if (type == 'incidents') {
      await MonitoringGateway.channel.invokeMethod<void>('dismiss', {
        'uid': repository.uid,
        'id': id,
      });
    }
    await AttachmentStore(repository).cleanup();
  });

  Future<void> updateCondition(String id, String condition) =>
      operation(() async {
        await repository.updateIncident(id, condition: condition);
        if (condition == 'SAFE') {
          await MonitoringGateway.channel.invokeMethod<void>('safe', {
            'uid': repository.uid,
            'id': id,
          });
        }
      });
  Future<SyncReport> sync() async {
    if (await repository.preference('deleting') != null) {
      throw const AppFailure('Retome a exclusão em Minha conta.');
    }
    // A deliberate retry can recover after connectivity, verification or
    // backend configuration is repaired. Conflicts still require review.
    await repository.store.db.update(
      'outbox',
      {'status': 'PENDING', 'next_attempt_at': 0},
      where: "user_id=? AND status IN ('PENDING','DENIED')",
      whereArgs: [repository.uid],
    );
    final report = await _syncEngine.synchronize();
    _notice = report.message;
    if (ref.mounted) await refresh();
    return report;
  }

  Future<void> _syncQuietly({bool pullRemote = false}) async {
    if (_busy || !ref.mounted) return;
    if (await repository.preference('deleting') != null) return;
    try {
      if (pullRemote) {
        await ref.read(authRepositoryProvider).refreshUser();
        if (!ref.mounted || ref.read(activeUidProvider) != repository.uid) {
          return;
        }
      }
      if (!pullRemote && await repository.pendingCount() == 0) return;
      final report = await _syncEngine.synchronize(pullRemote: pullRemote);
      _notice = report.message;
    } catch (_) {
      _notice =
          'Sincronização pendente. Seus registros permanecem no aparelho.';
    }
  }
}
