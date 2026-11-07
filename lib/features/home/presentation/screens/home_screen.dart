import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../../shared/widgets/zelo_logo.dart';
import '../../../monitoring/domain/monitoring_session.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final session = data.session;
      final status = data.issue != null
          ? 'Proteção não confirmada'
          : session == null
          ? 'Proteção desativada'
          : !data.running
          ? 'Verificando serviço Android'
          : outcomeLabel(session.status);
      final active =
          data.running && session?.status == 'ACTIVE' && data.issue == null;
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [ZeloLogo(size: 36), SizedBox(width: 8), Text('ZELO')],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Cuidado em cada caminho.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      active
                          ? Icons.verified_user_outlined
                          : Icons.shield_outlined,
                      color: active ? AppColors.protection : AppColors.navy,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (session != null)
                      Text(
                        'Início ${dateLabel(session.startedAt)} • ${session.position.label}',
                        textAlign: TextAlign.center,
                      ),
                    if (session != null && data.running)
                      Text(
                        'Duração: ${DateTime.now().toUtc().difference(session.startedAt).inMinutes} min',
                        textAlign: TextAlign.center,
                      ),
                    if (data.issue != null) Text(data.issue!),
                    if (session != null)
                      Text(
                        session.location?.describe(DateTime.now().toUtc()) ??
                            'Localização inicial indisponível. O monitoramento de sensores não depende de GPS.',
                      ),
                    const SizedBox(height: 16),
                    SegmentedButton<PhonePosition>(
                      segments: const [
                        ButtonSegment(
                          value: PhonePosition.pocket,
                          label: Text('Bolso'),
                          icon: Icon(Icons.phone_android),
                        ),
                        ButtonSegment(
                          value: PhonePosition.mount,
                          label: Text('Suporte'),
                          icon: Icon(Icons.two_wheeler),
                        ),
                      ],
                      selected: {data.position},
                      onSelectionChanged: data.busy
                          ? null
                          : (positions) => uiAction(
                              context,
                              () => app.selectPosition(positions.single),
                            ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: data.busy
                          ? null
                          : () async {
                              if (session != null && data.running) {
                                if (await confirmAction(
                                      context,
                                      'Encerrar proteção?',
                                      'O monitoramento será encerrado manualmente. Alertas em andamento precisam ser resolvidos primeiro.',
                                    ) &&
                                    context.mounted) {
                                  await uiAction(context, app.stop);
                                }
                              } else if (!data.prepared) {
                                context.push('/preparar');
                              } else {
                                await uiAction(context, app.start);
                              }
                            },
                      child: Text(
                        data.busy
                            ? 'Aguarde…'
                            : session != null && data.running
                            ? 'Encerrar proteção'
                            : !data.prepared
                            ? 'Preparar proteção'
                            : 'Iniciar proteção',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(60),
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
              icon: const Icon(Icons.sos),
              label: const Text('SOS — Preciso de ajuda'),
            ),
            const SizedBox(height: 12),
            const Text(
              'SOS disponível mesmo sem sessão. Mensagens exigem sua ação para enviar; abrir outro app não confirma envio ou entrega.',
            ),
            if (data.unresolved != null)
              TextButton(
                onPressed: () => context.push('/ajuda/${data.unresolved!.id}'),
                child: const Text('Revisar pedido de ajuda'),
              ),
            const SizedBox(height: 16),
            Text('${data.pendingSync} operações de sincronização pendentes.'),
            if (data.notice != null) Text(data.notice!),
            const SizedBox(height: 16),
            const Text(
              'Detecção experimental, ainda sujeita à calibração física. Sem rastreamento GPS contínuo. O ZELO é auxiliar e não substitui equipamentos de proteção ou serviços de emergência.',
            ),
          ],
        ),
      );
    },
  );
}
