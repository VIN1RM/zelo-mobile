import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/platform/device_permissions.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../emergency/data/location_gateway.dart';

class PreparationScreen extends StatelessWidget {
  const PreparationScreen({super.key});
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) => Scaffold(
      appBar: AppBar(title: const Text('Preparar proteção')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Você controla quando o monitoramento começa e termina. Confira os recursos antes de iniciar.',
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text('${data.contacts.length} contatos cadastrados'),
            subtitle: const Text('Pelo menos um é obrigatório.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/contatos'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Permitir notificações'),
            subtitle: const Text(
              'Necessárias para avisos e ações do alerta com a tela bloqueada.',
            ),
            onTap: () => uiAction(context, () async {
              final status = await DevicePermissions.requestNotifications();
              if (!status) await DevicePermissions.openSettings();
            }),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Permitir localização pontual'),
            subtitle: const Text(
              'Consultada ao iniciar e em emergências. Sem GPS, o monitoramento local continua com essa limitação.',
            ),
            onTap: () => uiAction(context, () async {
              await LocationGateway().request();
            }),
          ),
          ListTile(
            leading: const Icon(Icons.sensors),
            title: const Text('Conferir sensores e bateria'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/ajustes/diagnostico'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Escolha Bolso ou Suporte no início. O funcionamento com a tela bloqueada varia por aparelho. A detecção é experimental e pode deixar de identificar situações ou gerar falsos alertas.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: data.busy
                ? null
                : () async {
                    if (await uiAction(context, app.prepare) &&
                        context.mounted) {
                      context.go('/inicio');
                    }
                  },
            child: const Text('Concluir preparação'),
          ),
        ],
      ),
    ),
  );
}
