import 'package:flutter/services.dart';

abstract final class DevicePermissions {
  static const channel = MethodChannel('br.com.zelo/permissions');
  static Future<bool> notificationsGranted() async =>
      await channel.invokeMethod<bool>('notificationsGranted') ?? false;
  static Future<bool> requestNotifications() async =>
      await channel.invokeMethod<bool>('requestNotifications') ?? false;
  static Future<void> openSettings() =>
      channel.invokeMethod<void>('openSettings');
}
