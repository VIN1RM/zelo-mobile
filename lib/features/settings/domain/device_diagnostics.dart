/// Resource availability is not evidence of a running monitoring service.
class DeviceDiagnostics {
  const DeviceDiagnostics({
    required this.androidApi,
    required this.accelerometerAvailable,
    required this.gyroscopeAvailable,
    required this.notificationsEnabled,
    required this.batteryOptimizationExempt,
  });

  final int androidApi;
  final bool accelerometerAvailable;
  final bool gyroscopeAvailable;
  final bool notificationsEnabled;
  final bool batteryOptimizationExempt;
}
