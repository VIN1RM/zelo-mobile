import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/app_failure.dart';
import '../domain/reminder_settings.dart';

final reminderGatewayProvider = Provider<ReminderGateway>(
  (ref) => ReminderGateway(),
);

class ReminderGateway {
  static const channel = MethodChannel('br.com.zelo/reminders');
  Future<ReminderSettings> load(String uid) async {
    final data = await channel.invokeMapMethod<String, dynamic>('load', {
      'uid': uid,
    });
    return ReminderSettings.fromJson(data ?? {});
  }

  Future<void> save(String uid, ReminderSettings settings) async {
    if (settings.error != null) throw AppFailure(settings.error!);
    try {
      await channel.invokeMethod<void>('save', {
        'uid': uid,
        ...settings.toJson(),
      });
    } on PlatformException catch (error) {
      throw AppFailure(
        error.message ?? 'Não foi possível salvar os lembretes.',
      );
    }
  }

  Future<void> activate(String? uid) async {
    try {
      await channel.invokeMethod<void>('activate', {'uid': uid});
    } on MissingPluginException {
      return;
    }
  }

  Future<void> remove(String uid) =>
      channel.invokeMethod<void>('remove', {'uid': uid});
}
