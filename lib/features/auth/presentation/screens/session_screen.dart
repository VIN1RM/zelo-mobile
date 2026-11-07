import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_layout.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authUserProvider);
    return AuthLayout(
      title: 'Preparando o ZELO',
      children: [
        if (state.hasError) ...[
          const Text('Não foi possível consultar sua sessão. Tente novamente.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(authUserProvider),
            child: const Text('Tentar novamente'),
          ),
          TextButton(
            onPressed: () => ref
                .read(authControllerProvider.notifier)
                .run((actions) => actions.repository.signOut()),
            child: const Text('Sair da conta'),
          ),
          const AuthFeedback(),
        ] else
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
