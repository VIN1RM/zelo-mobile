import 'package:flutter/services.dart';

import '../domain/device_diagnostics.dart';

class AndroidDiagnosticsGateway {
  const AndroidDiagnosticsGateway();

  static const channel = MethodChannel('br.com.zelo/device_diagnostics');

  Future<DeviceDiagnostics> read() async {
    final data = await channel.invokeMapMethod<String, dynamic>('read');
    if (data == null ||
        data['androidApi'] is! int ||
        data['accelerometerAvailable'] is! bool ||
        data['gyroscopeAvailable'] is! bool ||
        data['notificationsEnabled'] is! bool ||
        data['batteryOptimizationExempt'] is! bool) {
      throw const FormatException('Invalid Android diagnostics response');
    }
    return DeviceDiagnostics(
      androidApi: data['androidApi'] as int,
      accelerometerAvailable: data['accelerometerAvailable'] as bool,
      gyroscopeAvailable: data['gyroscopeAvailable'] as bool,
      notificationsEnabled: data['notificationsEnabled'] as bool,
      batteryOptimizationExempt: data['batteryOptimizationExempt'] as bool,
    );
  }

  Future<void> openNotificationSettings() =>
      channel.invokeMethod<void>('openNotificationSettings');
}
