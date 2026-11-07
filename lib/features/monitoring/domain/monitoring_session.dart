import '../../emergency/domain/location_snapshot.dart';

enum PhonePosition { pocket, mount }

extension PhonePositionLabel on PhonePosition {
  String get label => this == PhonePosition.pocket ? 'Bolso' : 'Suporte';
}

class MonitoringSession {
  const MonitoringSession({
    required this.id,
    required this.startedAt,
    required this.status,
    required this.position,
    this.endedAt,
    this.location,
    this.local = true,
    this.preserved = false,
  });
  final bool local;
  final bool preserved;
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status;
  final PhonePosition position;
  final LocationSnapshot? location;
  bool get operational =>
      local && const ['PREPARING', 'ACTIVE', 'LIMITED'].contains(status);
  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endedAt': endedAt?.millisecondsSinceEpoch,
    'status': status,
    'position': position.name,
    'location': location?.toJson(),
    'local': local,
    'preserved': preserved,
  };
  factory MonitoringSession.fromJson(Map<String, dynamic> data) =>
      MonitoringSession(
        id: data['id'] as String,
        local: data['local'] as bool? ?? true,
        preserved: data['preserved'] as bool? ?? false,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          data['startedAt'] as int,
          isUtc: true,
        ),
        endedAt: data['endedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                data['endedAt'] as int,
                isUtc: true,
              ),
        status: data['status'] as String,
        position: PhonePosition.values.byName(data['position'] as String),
        location: data['location'] == null
            ? null
            : LocationSnapshot.fromJson(
                Map<String, dynamic>.from(data['location'] as Map),
              ),
      );
}
