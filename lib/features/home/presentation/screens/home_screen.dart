import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_view.dart';
import '../widgets/phone_position_selector.dart';
import '../../../monitoring/domain/monitoring_session.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final session = data.session;
      final active =
          data.running && session?.status == 'ACTIVE' && data.issue == null;
      final status = data.issue != null
          ? 'Proteção não confirmada'
          : session == null
          ? 'Proteção desativada'
          : !data.running
          ? 'Verificando monitoramento'
          : outcomeLabel(session.status);
      Future<void> toggleProtection() async {
        if (session != null && data.running) {
          if (await confirmAction(
                context,
                'Encerrar proteção?',
                'O monitoramento será encerrado. Resolva qualquer alerta em andamento antes de continuar.',
              ) &&
              context.mounted) {
            await uiAction(context, app.stop);
          }
        } else if (!data.prepared) {
          context.push('/preparar');
        } else {
          await uiAction(context, app.start);
        }
      }

      return Scaffold(
        appBar: AppHeader(
          title: const Text('Início'),
          actions: [
            IconButton(
              tooltip: 'Preparar proteção',
              onPressed: () => context.push('/preparar'),
              icon: const Icon(AppIcons.factCheckOutlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: AppScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const SectionHeading(
              'Cuidado em cada caminho.',
              subtitle: 'Você escolhe quando sua proteção começa.',
            ),
            _ProtectionHero(
              active: active,
              status: status,
              message:
                  data.issue ??
                  (session == null
                      ? 'Inicie antes de sair. O ZELO acompanha os movimentos do celular durante o trajeto.'
                      : 'Início ${dateLabel(session.startedAt)} · ${session.position.label}${data.running ? '\n${DateTime.now().toUtc().difference(session.startedAt).inMinutes} min de monitoramento' : ''}'),
              action: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navy,
                ),
                onPressed: data.busy ? null : toggleProtection,
                icon: Icon(
                  session != null && data.running
                      ? AppIcons.stopCircleOutlined
                      : AppIcons.playArrowRounded,
                ),
                label: LoadingLabel(
                  loading: data.busy,
                  label: session != null && data.running
                      ? 'Encerrar proteção'
                      : !data.prepared
                      ? 'Preparar proteção'
                      : 'Iniciar proteção',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeading(
                    'Precisa de ajuda agora?',
                    subtitle:
                        'O SOS está disponível mesmo sem um trajeto iniciado.',
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emergency,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: data.emergencyBusy
                        ? null
                        : () async {
                            String? id;
                            if (await uiAction(context, () async {
                                  id = await app.sos();
                                }) &&
                                context.mounted &&
                                id != null) {
                              context.push('/ajuda/$id');
                            }
                          },
                    icon: const Icon(AppIcons.sosRounded),
                    label: LoadingLabel(
                      loading: data.emergencyBusy,
                      label: 'SOS — Preciso de ajuda',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Você escolhe o contato e conclui o envio da mensagem.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (data.unresolved != null)
                    TextButton.icon(
                      onPressed: () =>
                          context.push('/ajuda/${data.unresolved!.id}'),
                      icon: const Icon(AppIcons.pendingActionsRounded),
                      label: const Text('Revisar pedido de ajuda'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeading(
                    'Onde ficará seu celular?',
                    subtitle:
                        'Escolha a posição para ajustar a análise dos movimentos.',
                  ),
                  PhonePositionSelector(
                    position: data.position,
                    onChanged: data.busy
                        ? null
                        : (position) => uiAction(
                            context,
                            () => app.selectPosition(position),
                          ),
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      session.location?.describe(DateTime.now().toUtc()) ??
                          'Localização inicial indisponível. A análise dos sensores continua sem GPS.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppActionTile(
              icon: AppIcons.peopleOutlineRounded,
              title: 'Seus contatos de emergência',
              subtitle: data.contacts.isEmpty
                  ? 'Adicione alguém de confiança antes de iniciar.'
                  : '${data.contacts.length} de 3 contatos cadastrados',
              onTap: () => context.go('/contatos'),
            ),
            AppActionTile(
              icon: AppIcons.cloudSyncOutlined,
              title: data.pendingSync == 0
                  ? 'Nenhum envio pendente'
                  : '${data.pendingSync} atualizações aguardando envio',
              subtitle:
                  'Seus registros são salvos no aparelho. A sincronização é automática com o app aberto e internet.',
              onTap: () => context.push('/sincronizacao'),
            ),
            const SizedBox(height: 16),
            const StatusPanel(
              title: 'Uma ajuda extra no caminho',
              message:
                  'A detecção é experimental e pode gerar falsos alertas ou não identificar situações. O ZELO não substitui equipamentos de proteção nem serviços de emergência.',
              icon: AppIcons.infoOutlineRounded,
            ),
          ],
        ),
      );
    },
  );
}

class _ProtectionHero extends StatelessWidget {
  const _ProtectionHero({
    required this.active,
    required this.status,
    required this.message,
    required this.action,
  });
  final bool active;
  final String status;
  final String message;
  final Widget action;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.navy, AppColors.teal],
      ),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                active ? AppIcons.verifiedUserRounded : AppIcons.shieldOutlined,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 24),
          action,
        ],
      ),
    ),
  );
}
