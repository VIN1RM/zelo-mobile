import '../widgets/about_dialog.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/platform/device_permissions.dart';
import '../../../../shared/widgets/app_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) => Scaffold(
      appBar: AppHeader(title: const Text('Ajustes')),
      body: AppScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const SectionHeading(
            'Do seu jeito',
            subtitle:
                'Cuide da sua conta e deixe o aparelho pronto para o próximo trajeto.',
          ),
          AppActionTile(
            icon: AppIcons.personOutlineRounded,
            title: 'Minha conta',
            subtitle: 'Nome, acesso e exclusão dos seus dados',
            onTap: () => context.push('/conta'),
          ),
          const SizedBox(height: 20),
          const SectionHeading('Pronto para sair'),
          AppActionTile(
            icon: Icons.notifications_active_outlined,
            title: 'Lembretes de proteção',
            subtitle: 'Escolha dias e horários para lembrar de iniciar',
            onTap: () => context.push('/lembretes'),
          ),
          AppActionTile(
            icon: AppIcons.sensorsRounded,
            title: 'Recursos do aparelho',
            subtitle:
                'Câmera, coordenadas, notificação de teste e eixos X, Y e Z',
            onTap: () => context.push('/ajustes/recursos'),
          ),
          AppActionTile(
            icon: AppIcons.factCheckOutlined,
            title: 'Preparar proteção',
            subtitle: 'Revise os passos antes de começar',
            onTap: () => context.push('/preparar'),
          ),
          AppActionTile(
            icon: AppIcons.sensorsRounded,
            title: 'Diagnóstico do aparelho',
            subtitle: 'Confira sensores, notificações e bateria',
            onTap: () => context.push('/ajustes/diagnostico'),
          ),
          AppActionTile(
            icon: AppIcons.notificationsOutlined,
            title: 'Permissões do aplicativo',
            subtitle: 'Gerencie o acesso nos ajustes do Android',
            external: true,
            onTap: () => uiAction(context, DevicePermissions.openSettings),
          ),
          AppActionTile(
            icon: AppIcons.playCircleOutlineRounded,
            title: 'Conhecer o alerta',
            subtitle: 'Demonstração sem mensagens ou registros reais',
            onTap: () => context.push('/demonstracao'),
          ),
          const SizedBox(height: 20),
          const SectionHeading('Seus dados'),
          AppActionTile(
            icon: AppIcons.cloudSyncOutlined,
            title: 'Sincronização',
            subtitle: data.pendingSync == 0
                ? 'Nenhum envio pendente · sincronização automática'
                : '${data.pendingSync} atualizações aguardando envio',
            onTap: () => context.push('/sincronizacao'),
          ),
          AppActionTile(
            icon: AppIcons.privacyTipOutlined,
            title: 'Privacidade e armazenamento',
            subtitle: 'Entenda o que fica no aparelho e na nuvem',
            onTap: () => context.push('/privacidade'),
          ),
          const SizedBox(height: 20),
          const SectionHeading('Sobre o ZELO'),
          AppActionTile(
            icon: AppIcons.infoOutlineRounded,
            title: 'Sobre e licenças',
            subtitle: 'Versão e créditos do aplicativo',
            onTap: () async {
              final openLicenses = await showZeloAboutDialog(context);
              if (openLicenses && context.mounted) context.push('/licencas');
            },
          ),
          Card(
            child: ExpansionTile(
              leading: const IconBadge(AppIcons.historyRounded),
              title: const Text('Verificações recentes'),
              subtitle: const Text('Atividade do aplicativo neste aparelho'),
              children: [
                Builder(
                  builder: (context) => FutureBuilder(
                    future: app.repository.store.db.query(
                      'diagnostics',
                      where: 'user_id=?',
                      whereArgs: [app.repository.uid],
                      orderBy: 'created_at DESC',
                      limit: 20,
                    ),
                    builder: (context, snapshot) => Column(
                      children: [
                        if (snapshot.hasError)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Não foi possível consultar as verificações. Tente abrir esta seção novamente.',
                            ),
                          ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              semanticsLabel: 'Consultando verificações',
                            ),
                          ),
                        if (snapshot.hasData && snapshot.data!.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Nenhuma atividade recente para mostrar.',
                            ),
                          ),
                        for (final log in snapshot.data ?? [])
                          ListTile(
                            title: Text(diagnosticLabel(log['code'])),
                            subtitle: Text(
                              dateLabel(
                                DateTime.fromMillisecondsSinceEpoch(
                                  log['created_at'] as int,
                                  isUtc: true,
                                ),
                              ),
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Sem dados pessoais. As verificações ficam por até sete dias, com limite de 200 registros.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const StatusPanel(
            title: 'Em evolução, com transparência',
            message:
                'ZELO 1.0.0 · Em desenvolvimento. A detecção é experimental. Os testes físicos e os critérios de publicação ainda estão em validação.',
            icon: AppIcons.shieldOutlined,
          ),
        ],
      ),
    ),
  );
}
