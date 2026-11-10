import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import '../../../../features/history/data/attachment_store.dart';
import '../../../../shared/widgets/app_view.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) => Scaffold(
      appBar: AppHeader(title: const Text('Privacidade e armazenamento')),
      body: OrganizedListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SectionHeading(
            'Seus dados, com clareza',
            subtitle: 'Entenda o que é salvo, compartilhado e excluído.',
          ),
          const SizedBox(height: 16),
          const SectionHeading('Conta e sincronização'),
          const Text(
            'Nome e e-mail são tratados pelo Firebase Authentication para acesso à conta. Contatos, sessões e ocorrências são salvos no banco protegido do aparelho; metadados são sincronizados com o projeto Firebase do ZELO quando há acesso ao servidor.',
          ),
          const SizedBox(height: 16),
          const StatusPanel(
            title: 'Você controla o compartilhamento',
            message:
                'Não gravamos rotas contínuas nem amostras dos sensores. A localização é pontual. Fotos e observações ficam somente no aparelho. Você decide quando exportar ou compartilhar.',
            icon: AppIcons.privacyTipOutlined,
          ),
          const SizedBox(height: 16),
          const SectionHeading('Por quanto tempo os registros ficam salvos?'),
          const Text(
            'Registros comuns não preservados podem ser removidos após 90 dias. Emergências não canceladas e SOS são preservados por padrão. Fotos acompanham a ocorrência. Exclusões na nuvem só são consideradas concluídas após confirmação do servidor.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Não reinstale ou apague dados enquanto houver exclusões pendentes: a fila local pode ser perdida. Fotos locais não serão recuperadas em outro aparelho. A exclusão da conta exige internet e está disponível em Minha conta.',
          ),
          const SizedBox(height: 16),
          const SectionHeading('Armazenamento neste aparelho'),
          Text(
            '${data.sessions.length} trajetos • ${data.incidents.length} ocorrências • ${data.pendingSync} operações pendentes',
          ),
          OutlinedButton(
            onPressed: data.busy
                ? null
                : () => uiAction(
                    context,
                    () => app.operation(() async {
                      await app.repository.retain();
                      await AttachmentStore(app.repository).cleanup();
                    }),
                    success: 'Retenção aplicada aos registros elegíveis.',
                  ),
            child: const Text('Aplicar retenção agora'),
          ),
          const SizedBox(height: 16),
          const SectionHeading('O que acontece ao excluir?'),
          const Text(
            'Após excluir a conta, um marcador técnico mínimo permanece no servidor para bloquear reenvios antigos. Ele contém somente o identificador pseudônimo, a fase e a data da exclusão.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Ao excluir um contato ou registro, seus canais, localização e notas são removidos do marcador de sincronização. IDs, revisões, datas e resultado original podem permanecer para impedir restauração por dados antigos. A exclusão da conta remove esses registros de domínio.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Política de privacidade em revisão: responsável e canal público de contato ainda não definidos. Esta é uma versão de desenvolvimento.',
          ),
        ],
      ),
    ),
  );
}
