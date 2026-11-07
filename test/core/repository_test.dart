import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zelo_mobile/core/data/zelo_repository.dart';
import 'package:zelo_mobile/core/database/local_store.dart';
import 'package:zelo_mobile/core/domain/app_failure.dart';
import 'package:zelo_mobile/features/emergency/domain/incident.dart';
import 'package:zelo_mobile/features/emergency/domain/location_snapshot.dart';
import 'package:zelo_mobile/features/monitoring/domain/monitoring_session.dart';

void main() {
  sqfliteFfiInit();
  late LocalStore store;
  late ZeloRepository repository;
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
    repository = ZeloRepository(store, 'owner-a');
  });
  tearDown(() => store.close());
  test(
    'incident deletion removes location and notes but keeps identity',
    () async {
      final time = DateTime.now().toUtc();
      await repository.saveIncident(
        Incident(
          id: 'private-incident',
          type: 'MANUAL_SOS',
          occurredAt: time,
          outcome: 'HELP_REQUESTED',
          condition: 'NEEDS_HELP',
          preserved: true,
          notes: 'Private note',
          location: LocationSnapshot(
            latitude: -23,
            longitude: -46,
            accuracy: 10,
            capturedAt: time,
          ),
        ),
      );
      await repository.deleteRecord('incidents', 'private-incident');
      final deleted = LocalStore.decode(
        (await repository.rows('incidents', deleted: true)).single,
      );
      expect(deleted['location'], isNull);
      expect(deleted['notes'], isNull);
      expect(deleted['id'], 'private-incident');
      expect(deleted['outcome'], 'HELP_REQUESTED');
      expect(await repository.incidents(), isEmpty);
    },
  );
  test(
    'contact deletion removes personal channels from its tombstone',
    () async {
      await repository.saveContact(
        name: 'Pessoa privada',
        phone: '+5511987654321',
        email: 'pessoa@example.test',
      );
      final id = (await repository.contacts()).single.id;
      await repository.deleteContact(id);
      final deleted = LocalStore.decode(
        (await repository.rows('contacts', deleted: true)).single,
      );
      expect(deleted['name'], 'Registro excluído');
      expect(deleted['phone'], isNull);
      expect(deleted['email'], 'deleted@zelo.invalid');
      expect(await repository.contacts(), isEmpty);
    },
  );
  Future<void> contact(int i) => repository.saveContact(
    name: 'Contato $i',
    phone: '+551199999000$i',
    email: '',
  );
  test(
    'contact limit, normalization and duplicate channels are transactional',
    () async {
      await contact(1);
      await contact(2);
      await contact(3);
      await expectLater(contact(4), throwsA(isA<AppFailure>()));
      expect((await repository.contacts()).length, 3);
      expect(await repository.pendingCount(), 3);
      await expectLater(
        repository.saveContact(
          name: 'Duplicado',
          phone: '+55 (11) 99999-0001',
          email: '',
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'reordering swaps priorities without violating uniqueness and coalesces outbox',
    () async {
      await contact(1);
      await contact(2);
      await contact(3);
      final original = await repository.contacts();
      await repository.reorderContacts(
        original.reversed.map((c) => c.id).toList(),
      );
      expect(
        (await repository.contacts()).map((c) => c.id),
        original.reversed.map((c) => c.id),
      );
      expect((await repository.contacts()).map((c) => c.priority), [1, 2, 3]);
      expect(await repository.pendingCount(), 3);
    },
  );
  test('last contact cannot be deleted during operational session', () async {
    await contact(1);
    await repository.saveSession(
      MonitoringSession(
        id: 'session',
        startedAt: DateTime.now().toUtc(),
        status: 'ACTIVE',
        position: PhonePosition.pocket,
      ),
    );
    await expectLater(
      repository.deleteContact((await repository.contacts()).single.id),
      throwsA(isA<AppFailure>()),
    );
    expect((await repository.contacts()).length, 1);
  });
  test('only one operational session exists per local UID', () async {
    await repository.saveSession(
      MonitoringSession(
        id: 'first',
        startedAt: DateTime.now().toUtc(),
        status: 'ACTIVE',
        position: PhonePosition.pocket,
      ),
    );
    await expectLater(
      repository.saveSession(
        MonitoringSession(
          id: 'second',
          startedAt: DateTime.now().toUtc(),
          status: 'PREPARING',
          position: PhonePosition.mount,
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect((await repository.sessions()).length, 1);
    expect(await repository.pendingCount(), 1);
  });
  test('UID isolation prevents access and cross-user parent links', () async {
    await contact(1);
    await repository.saveSession(
      MonitoringSession(
        id: 'private-session',
        startedAt: DateTime.now().toUtc(),
        status: 'COMPLETED',
        position: PhonePosition.pocket,
      ),
    );
    final other = ZeloRepository(store, 'owner-b');
    expect(await other.contacts(), isEmpty);
    expect(await other.sessions(), isEmpty);
    await expectLater(
      other.saveIncident(
        Incident(
          id: 'cross',
          type: 'MANUAL_SOS',
          sessionId: 'private-session',
          occurredAt: DateTime.now().toUtc(),
          outcome: 'HELP_REQUESTED',
          condition: 'NEEDS_HELP',
          preserved: true,
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );
  });
  test(
    'condition updates append history and preserve original outcome',
    () async {
      await repository.saveIncident(
        Incident(
          id: 'incident',
          type: 'MANUAL_SOS',
          occurredAt: DateTime.now().toUtc(),
          outcome: 'HELP_REQUESTED',
          condition: 'NEEDS_HELP',
          preserved: true,
        ),
      );
      await repository.updateIncident('incident', condition: 'SAFE');
      final incident = (await repository.incidents()).single;
      expect(incident.outcome, 'HELP_REQUESTED');
      expect(incident.condition, 'SAFE');
      expect((await repository.rows('updates')).length, 1);
    },
  );
  test(
    'retention removes eligible records but preserves emergencies and SOS',
    () async {
      final old = DateTime.now().toUtc().subtract(const Duration(days: 91));
      await repository.saveIncident(
        Incident(
          id: 'cancelled',
          type: 'POSSIBLE_ACCIDENT',
          occurredAt: old,
          outcome: 'CANCELLED',
          condition: 'SAFE',
          preserved: false,
        ),
      );
      await repository.saveIncident(
        Incident(
          id: 'sos',
          type: 'MANUAL_SOS',
          occurredAt: old,
          outcome: 'HELP_REQUESTED',
          condition: 'UNKNOWN',
          preserved: true,
        ),
      );
      await repository.retain();
      expect((await repository.incidents()).map((i) => i.id), ['sos']);
      final tombstone = (await repository.rows(
        'incidents',
        deleted: true,
      )).firstWhere((r) => r['id'] == 'cancelled');
      expect(tombstone['is_deleted'], 1);
      await expectLater(
        repository.saveIncident(
          Incident(
            id: 'cancelled',
            type: 'POSSIBLE_ACCIDENT',
            occurredAt: old,
            outcome: 'CANCELLED',
            condition: 'SAFE',
            preserved: false,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('entity and outbox roll back together', () async {
    await expectLater(
      store.db.transaction((tx) async {
        await repository.put(tx, 'profiles', {
          'id': 'owner-a',
          'name': 'Rider',
          'email': 'rider@example.com',
        });
        throw const AppFailure('Abort transaction');
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(await repository.rows('profiles'), isEmpty);
    expect(await repository.pendingCount(), 0);
  });
  test('stale contact form cannot overwrite a newer local revision', () async {
    await contact(1);
    final original = (await repository.contacts()).single;
    await repository.saveContact(
      id: original.id,
      name: 'Nome mais recente',
      phone: original.phone!,
      email: '',
    );
    await expectLater(
      repository.saveContact(
        id: original.id,
        expectedRevision: original.revision,
        name: 'Edição antiga',
        phone: original.phone!,
        email: '',
      ),
      throwsA(isA<AppFailure>()),
    );
    expect((await repository.contacts()).single.name, 'Nome mais recente');
  });
  test('pending alerts cannot receive post-event condition updates', () async {
    await repository.saveIncident(
      Incident(
        id: 'pending',
        type: 'POSSIBLE_ACCIDENT',
        occurredAt: DateTime.now().toUtc(),
        deadline: DateTime.now().toUtc().add(const Duration(seconds: 30)),
        outcome: 'PENDING',
        condition: 'UNKNOWN',
        preserved: true,
      ),
    );
    await expectLater(
      repository.updateIncident('pending', condition: 'SAFE'),
      throwsA(isA<AppFailure>()),
    );
    expect((await repository.incidents()).single.outcome, 'PENDING');
  });
}
