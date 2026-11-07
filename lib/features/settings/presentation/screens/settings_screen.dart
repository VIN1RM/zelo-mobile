import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/platform/device_permissions.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../../shared/widgets/zelo_logo.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) => Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: ZeloLogo()),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Minha conta'),
              subtitle: const Text('Perfil, saída e exclusão de conta'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/conta'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Diagnóstico do aparelho'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/ajustes/diagnostico'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Permissões Android'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => DevicePermissions.openSettings(),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Demonstração isolada'),
              subtitle: const Text('Sem mensagens ou registros reais'),
              onTap: () => context.push('/demonstracao'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync),
              title: Text('Sincronização • ${data.pendingSync} pendências'),
              subtitle: Text(
                data.notice ?? 'Registros são salvos primeiro no aparelho.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/sincronizacao'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacidade e armazenamento'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/privacidade'),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/preparar'),
            child: const Text('Revisar preparação'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre e licenças'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'ZELO',
              applicationVersion: '1.0.0 • Desenvolvimento',
              applicationLegalese: 'Aplicativo auxiliar e experimental.',
            ),
          ),
          ExpansionTile(
            title: const Text('Diagnósticos recentes'),
            children: [
              FutureBuilder(
                future: app.repository.store.db.query(
                  'diagnostics',
                  where: 'user_id=?',
                  whereArgs: [app.repository.uid],
                  orderBy: 'created_at DESC',
                  limit: 20,
                ),
                builder: (context, snapshot) => Column(
                  children: [
                    for (final log in snapshot.data ?? [])
                      ListTile(
                        title: Text('${log['code']}'),
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
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Códigos locais sem dados pessoais. Retenção de sete dias e até 200 registros.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Text(
            'ZELO 1.0.0 • Em desenvolvimento. Detecção experimental. A validação física e os critérios de publicação ainda precisam ser concluídos.',
          ),
        ],
      ),
    ),
  );
}
