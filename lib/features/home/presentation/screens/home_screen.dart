import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield, color: AppColors.teal),
            SizedBox(width: 8),
            Text('ZELO'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Sua proteção começa com clareza.',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Chip(
                      avatar: Icon(Icons.construction_outlined, size: 18),
                      label: Text('Versão inicial'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'O ZELO ainda está sendo preparado',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O aplicativo ainda não monitora trajetos nem solicita '
                      'ajuda. Esses recursos só serão apresentados como '
                      'disponíveis depois de implementados e validados.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _PlannedFeature(
              icon: Icons.sensors_outlined,
              title: 'Monitoramento voluntário',
              description: 'Em avaliação para aparelhos Android.',
            ),
            const SizedBox(height: 12),
            const _PlannedFeature(
              icon: Icons.sos_outlined,
              title: 'Ajuda assistida',
              description: 'Mensagens não serão enviadas automaticamente.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannedFeature extends StatelessWidget {
  const _PlannedFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.teal),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}
