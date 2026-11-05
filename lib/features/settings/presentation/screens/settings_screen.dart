import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_placeholder.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Ajustes',
      icon: Icons.settings_outlined,
      description:
          'Permissões, privacidade e configurações estarão disponíveis '
          'conforme os recursos forem implementados.',
    );
  }
}
