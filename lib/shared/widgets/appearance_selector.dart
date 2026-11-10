import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme_mode_provider.dart';

class AppearanceSelector extends ConsumerWidget {
  const AppearanceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Aparência',
      initialValue: selected,
      icon: Icon(switch (selected) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      }),
      onSelected: (mode) async {
        try {
          await ref.read(themeModeProvider.notifier).select(mode);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Não foi possível salvar a aparência. Tente novamente.',
                ),
              ),
            );
          }
        }
      },
      itemBuilder: (context) => [
        for (final mode in ThemeMode.values)
          CheckedPopupMenuItem(
            value: mode,
            checked: selected == mode,
            child: Text(switch (mode) {
              ThemeMode.system => 'Seguir o celular',
              ThemeMode.light => 'Modo claro',
              ThemeMode.dark => 'Modo escuro',
            }),
          ),
      ],
    );
  }
}
