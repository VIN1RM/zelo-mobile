import 'package:flutter/material.dart';
import '../../../../shared/widgets/zelo_logo.dart';

Future<bool> showZeloAboutDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Center(child: ZeloLogo(size: 56)),
        title: const Text('Sobre o ZELO', textAlign: TextAlign.center),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('1.0.0 · Em desenvolvimento', textAlign: TextAlign.center),
            SizedBox(height: 16),
            Text(
              'Cuidado em cada caminho.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
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
          Column(
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
        ],
      ),
    ) ??
    false;
