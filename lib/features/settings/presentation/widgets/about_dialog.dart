import 'package:flutter/material.dart';
import '../../../../shared/widgets/zelo_logo.dart';

Future<bool> showZeloAboutDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 440),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        scrollable: true,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZeloLogo(size: 40),
            const SizedBox(height: 12),
            Text(
              'Sobre o ZELO',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('1.0.0 · Em desenvolvimento', textAlign: TextAlign.center),
            SizedBox(height: 16),
            Text(
              'Monitoramento voluntário, alertas locais e ajuda assistida para motociclistas.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Aplicativo auxiliar e experimental. Você escolhe quando iniciar a proteção e enviar mensagens.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actions: [
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 88).clamp(0, 392),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Ver licenças e créditos'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ),
        ],
      ),
    ) ??
    false;
