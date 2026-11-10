import 'app_header.dart';
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
          appBar: AppHeader(title: const Text('ZELO')),
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
  String message, {
  String? confirmLabel,
  bool? destructive,
}) async {
  final danger = destructive ?? title.toLowerCase().startsWith('excluir');
  final label =
      confirmLabel ??
      (danger
          ? 'Excluir'
          : title.startsWith('Testar')
          ? 'Abrir teste'
          : title.startsWith('Sair')
          ? 'Sair da conta'
          : title.startsWith('Encerrar')
          ? 'Encerrar proteção'
          : 'Continuar');
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          icon: Center(
            child: IconBadge(
              danger ? AppIcons.deleteOutline : AppIcons.infoOutlineRounded,
              tone: danger ? AppTone.danger : AppTone.neutral,
            ),
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  style: danger
                      ? FilledButton.styleFrom(
                          backgroundColor: AppTone.danger.foreground,
                          foregroundColor: Colors.white,
                        )
                      : null,
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(label),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ) ??
      false;
}
