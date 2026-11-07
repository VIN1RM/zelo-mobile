import 'location_snapshot.dart';

class Incident {
  const Incident({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.outcome,
    required this.condition,
    required this.preserved,
    this.sessionId,
    this.deadline,
    this.position,
    this.location,
    this.notes = '',
    this.detectionVersion,
  });
  final String id;
  final String type;
  final String? sessionId;
  final DateTime occurredAt;
  final DateTime? deadline;
  final String outcome;
  final String condition;
  final bool preserved;
  final String? position;
  final LocationSnapshot? location;
  final String notes;
  final String? detectionVersion;
  bool get pending => outcome == 'PENDING';
  String get label => type == 'MANUAL_SOS' ? 'SOS manual' : 'Possível acidente';
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'sessionId': sessionId,
    'occurredAt': occurredAt.millisecondsSinceEpoch,
    'deadline': deadline?.millisecondsSinceEpoch,
    'outcome': outcome,
    'condition': condition,
    'preserved': preserved,
    'position': position,
    'location': location?.toJson(),
    'notes': notes,
    'detectionVersion': detectionVersion,
  };
  factory Incident.fromJson(Map<String, dynamic> data) => Incident(
    id: data['id'] as String,
    type: data['type'] as String,
    sessionId: data['sessionId'] as String?,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(
      data['occurredAt'] as int,
      isUtc: true,
    ),
    deadline: data['deadline'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            data['deadline'] as int,
            isUtc: true,
          ),
    outcome: data['outcome'] as String,
    condition: data['condition'] as String,
    preserved: data['preserved'] as bool,
    position: data['position'] as String?,
    location: data['location'] == null
        ? null
        : LocationSnapshot.fromJson(
            Map<String, dynamic>.from(data['location'] as Map),
          ),
    notes: data['notes'] as String? ?? '',
    detectionVersion: data['detectionVersion'] as String?,
  );
}
