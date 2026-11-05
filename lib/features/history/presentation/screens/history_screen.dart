import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_placeholder.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Histórico',
      icon: Icons.history,
      description:
          'Trajetos e ocorrências ainda não são registrados pelo aplicativo.',
    );
  }
}
