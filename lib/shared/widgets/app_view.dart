import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/application/app_controller.dart';
import '../../core/domain/app_failure.dart';

class AppView extends ConsumerWidget {
  const AppView({required this.builder, super.key});
  final Widget Function(BuildContext, AppSnapshot, AppController) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(appControllerProvider)
      .when(
        data: (data) =>
            builder(context, data, ref.read(appControllerProvider.notifier)),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => Scaffold(
          appBar: AppBar(title: const Text('ZELO')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Não foi possível abrir os dados protegidos. Os arquivos existentes foram preservados. Tente novamente; não reinstale para resolver uma pendência de sincronização.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(localStoreProvider),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
}

Future<bool> uiAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AppFailure
                ? error.message
                : 'Não foi possível concluir. Confira permissões, conexão e tente novamente.',
          ),
        ),
      );
    }
    return false;
  }
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

String dateLabel(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String outcomeLabel(String outcome) => switch (outcome) {
  'PENDING' => 'Aguardando resposta',
  'CANCELLED' => 'Alerta cancelado',
  'HELP_REQUESTED' => 'Ajuda solicitada',
  'TIMED_OUT' => 'Sem resposta no prazo',
  'SAFE' => 'Estou bem',
  'NEEDS_HELP' => 'Preciso de ajuda',
  'UNKNOWN' => 'Condição não informada',
  'PREPARING' => 'Preparando',
  'ACTIVE' => 'Proteção ativa',
  'LIMITED' => 'Monitoramento limitado',
  'COMPLETED' => 'Trajeto encerrado',
  'INTERRUPTED' => 'Monitoramento interrompido',
  _ => outcome,
};
