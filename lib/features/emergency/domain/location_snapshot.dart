class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  });
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;

  bool isRecent(DateTime now) =>
      !capturedAt.isAfter(now) &&
      now.difference(capturedAt) <= const Duration(seconds: 60) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      accuracy >= 0 &&
      accuracy <= 100;
  String describe(DateTime now) =>
      '${isRecent(now) ? 'Localização recente' : 'Localização antiga ou imprecisa'} — ${capturedAt.toLocal()}, precisão estimada ${accuracy.round()} m';
  String get mapUrl => 'https://maps.google.com/?q=$latitude,$longitude';
  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'capturedAt': capturedAt.millisecondsSinceEpoch,
  };
  factory LocationSnapshot.fromJson(Map<String, dynamic> data) =>
      LocationSnapshot(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        accuracy: (data['accuracy'] as num).toDouble(),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(
          data['capturedAt'] as int,
          isUtc: true,
        ),
      );
}
