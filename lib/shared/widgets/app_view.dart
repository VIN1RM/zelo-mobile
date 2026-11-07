import '../presentation/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/application/app_controller.dart';
import '../../core/domain/app_failure.dart';
import 'app_components.dart';
export '../presentation/app_labels.dart';
export 'app_components.dart';

class AppView extends ConsumerWidget {
  const AppView({required this.builder, super.key});
  final Widget Function(BuildContext, AppSnapshot, AppController) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(appControllerProvider)
      .when(
        data: (data) =>
            builder(context, data, ref.read(appControllerProvider.notifier)),
        loading: () => const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(semanticsLabel: 'Abrindo seus dados'),
                SizedBox(height: 20),
                Text('Abrindo seus dados com segurança…'),
              ],
            ),
          ),
        ),
        error: (error, stack) => Scaffold(
          appBar: AppBar(title: const Text('ZELO')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AppEmptyState(
                icon: AppIcons.lockOutlineRounded,
                title: 'Seus dados foram preservados',
                message:
                    'Não foi possível abrir os dados protegidos agora. Tente novamente sem reinstalar o aplicativo.',
                action: FilledButton(
                  onPressed: () => ref.invalidate(localStoreProvider),
                  child: const Text('Tentar novamente'),
                ),
              ),
            ],
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
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
