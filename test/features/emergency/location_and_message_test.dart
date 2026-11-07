import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/core/sync/json_equality.dart';
import 'package:zelo_mobile/features/emergency/domain/location_snapshot.dart';
import 'package:zelo_mobile/features/emergency/domain/incident.dart';
import 'package:zelo_mobile/features/emergency/application/share_emergency.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);
  LocationSnapshot location(int ageMs, double accuracy) => LocationSnapshot(
    latitude: -23.5,
    longitude: -46.6,
    accuracy: accuracy,
    capturedAt: now.subtract(Duration(milliseconds: ageMs)),
  );
  test('GPS qualification applies precise time and accuracy boundaries', () {
    expect(location(60000, 100).isRecent(now), isTrue);
    expect(location(60001, 100).isRecent(now), isFalse);
    expect(location(1000, 100.01).isRecent(now), isFalse);
    expect(location(-1, 5).isRecent(now), isFalse);
    expect(location(1000, -1).isRecent(now), isFalse);
  });
  test(
    'message qualifies stale GPS and never confirms delivery or accident',
    () {
      final incident = Incident(
        id: 'i',
        type: 'MANUAL_SOS',
        occurredAt: now,
        outcome: 'HELP_REQUESTED',
        condition: 'NEEDS_HELP',
        preserved: true,
        location: location(61000, 10),
      );
      final text = ShareEmergency.message(incident, 'Rider', now);
      expect(text, contains('antiga ou imprecisa'));
      expect(text, contains('não confirma um acidente'));
      expect(text, contains('não são confirmados'));
      expect(
        ShareEmergency.message(incident, 'Rider', now, test: true),
        startsWith('TESTE'),
      );
    },
  );
  test(
    'idempotence comparison ignores map order but respects nested values',
    () {
      expect(
        sameJson(
          {
            'a': 1,
            'location': {'lat': 2, 'lng': 3},
          },
          {
            'location': {'lng': 3, 'lat': 2},
            'a': 1,
          },
        ),
        isTrue,
      );
      expect(sameJson({'a': 1}, {'a': 2}), isFalse);
    },
  );
}
