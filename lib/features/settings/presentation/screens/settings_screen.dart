import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/zelo_logo.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).asData?.value;
    final action = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: ZeloLogo()),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    user?.name.isNotEmpty == true ? user!.name : 'Minha conta',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(user?.email ?? ''),
                  const Text('E-mail verificado'),
                  if (action.hasError) Text(action.error.toString()),
                  TextButton(
                    onPressed: action.isLoading
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Sair da conta?'),
                                content: const Text(
                                  'Você precisará entrar novamente para acessar o ZELO.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Sair'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .run(
                                    (actions) => actions.repository.signOut(),
                                  );
                            }
                          },
                    child: const Text('Sair da conta'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Diagnóstico do aparelho'),
              subtitle: const Text(
                'Consulte sensores e notificações do Android.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/ajustes/diagnostico'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'O monitoramento e o SOS ainda estão em desenvolvimento. '
            'O diagnóstico não ativa a proteção.',
          ),
        ],
      ),
    );
  }
}
