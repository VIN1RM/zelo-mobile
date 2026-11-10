import '../../../../shared/widgets/app_components.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_layout.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider).asData?.value;
    final busy = ref.watch(authControllerProvider).isLoading;
    final wait = ref.read(authActionsProvider).resendWaitSeconds;
    return AuthLayout(
      title: 'Verifique seu e-mail',
      children: [
        Text(
          'Confirme o endereço ${user?.email ?? ''} pelo link de verificação.',
        ),
        const SizedBox(height: 12),
        Text(
          wait > 0
              ? 'Solicitação de verificação enviada. Confira a caixa de entrada e o spam.'
              : 'Se ainda não recebeu o link, solicite o envio abaixo.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Depois de abrir o link, volte aqui e toque em “Já verifiquei”.',
        ),
        const SizedBox(height: 20),
        const AuthFeedback(),
        FilledButton(
          onPressed: busy
              ? null
              : () => ref
                    .read(authControllerProvider.notifier)
                    .run((actions) => actions.checkVerification()),
          child: LoadingLabel(loading: busy, label: 'Já verifiquei'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy || wait > 0
              ? null
              : () => ref
                    .read(authControllerProvider.notifier)
                    .run((actions) => actions.sendVerification()),
          child: Text(
            wait > 0 ? 'Reenviar em ${wait}s' : 'Reenviar verificação',
          ),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => ref
                    .read(authControllerProvider.notifier)
                    .run((actions) => actions.repository.signOut()),
          child: const Text('Sair'),
        ),
      ],
    );
  }
}
