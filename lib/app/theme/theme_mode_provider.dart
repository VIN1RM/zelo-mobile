import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final appearanceStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const storageKey = 'appearance.themeMode';

  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> restore() async {
    try {
      final saved = await ref
          .read(appearanceStorageProvider)
          .read(key: storageKey);
      if (!ref.mounted) return;
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      if (ref.mounted) state = ThemeMode.system;
    }
  }

  Future<void> select(ThemeMode mode) async {
    await ref
        .read(appearanceStorageProvider)
        .write(key: storageKey, value: mode.name);
    if (ref.mounted) state = mode;
  }
}
