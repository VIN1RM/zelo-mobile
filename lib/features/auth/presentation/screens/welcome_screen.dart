import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_layout.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Cuidado em cada caminho.',
    children: [
      const Text(
        'O ZELO está sendo desenvolvido para oferecer monitoramento voluntário '
        'por sensores, alertas locais e ajuda assistida para motociclistas.',
      ),
      const SizedBox(height: 16),
      const Text(
        'A detecção é experimental. Mensagens exigem sua ação para enviar. '
        'O app não substitui equipamentos de segurança nem serviços de emergência.',
      ),
      const SizedBox(height: 16),
      const Text(
        'Entre para preparar o monitoramento experimental e acessar o SOS assistido.',
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => context.go('/criar-conta'),
        child: const Text('Criar conta'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => context.go('/entrar'),
        child: const Text('Já tenho conta'),
      ),
    ],
  );
}
