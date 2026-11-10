import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/share_emergency.dart';

class AlertScreen extends StatelessWidget {
  const AlertScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final incident = data.incidents.where((i) => i.id == id).firstOrNull;
      final seconds =
          data.alertRemainingSeconds ??
          (incident?.deadline == null
              ? 0
              : max(
                  0,
                  (incident!.deadline!
                              .difference(DateTime.now().toUtc())
                              .inMilliseconds /
                          1000)
                      .ceil(),
                ));
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppHeader(
            automaticallyImplyLeading: false,
            title: const Text('Possível acidente'),
          ),
          bottomNavigationBar: incident?.pending == true
              ? ActionFooter(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTone.positive.foreground,
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          incident?.pending == true && !data.emergencyBusy
                          ? () => uiAction(
                              context,
                              () => app.resolve(id, 'CANCELLED'),
                            )
                          : null,
                      child: const Text('Estou bem'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTone.danger.foreground,
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          incident?.pending == true && !data.emergencyBusy
                          ? () => uiAction(
                              context,
                              () => app.resolve(id, 'HELP_REQUESTED'),
                            )
                          : null,
                      child: const Text('Preciso de ajuda'),
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (incident?.pending == true) ...[
                  AlertCountdown(seconds: seconds),
                  const SizedBox(height: 24),
                ],
                Text(
                  incident?.pending == true
                      ? 'Você está bem?'
                      : outcomeLabel(
                          incident?.outcome ?? 'Registro indisponível',
                        ),
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const StatusPanel(
                  title: 'Detectamos um movimento suspeito',
                  message:
                      'Isso não confirma um acidente. Se estiver bem, cancele o alerta. Sem resposta, o ZELO preparará um pedido de ajuda; nenhuma mensagem será enviada automaticamente.',
                  icon: AppIcons.infoOutlineRounded,
                  tone: AppTone.warning,
                ),
                const SizedBox(height: 24),
                if (incident?.pending != true)
                  TextButton(
                    onPressed: () => context.go('/inicio'),
                    child: const Text('Voltar ao início'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String? contactId;
  bool sharing = false;
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final incident = data.incidents
          .where((i) => i.id == widget.id)
          .firstOrNull;
      final contact =
          data.contacts.where((c) => c.id == contactId).firstOrNull ??
          data.contacts.firstOrNull;
      if (incident == null) {
        return Scaffold(
          appBar: AppHeader(title: const Text('Pedir ajuda')),
          body: const Center(
            child: Text('Registro não encontrado nesta conta.'),
          ),
        );
      }
      final name = ref.watch(authUserProvider).asData?.value?.name ?? '';
      Future<void> share(String channel) async {
        setState(() => sharing = true);
        try {
          await uiAction(
            context,
            () => ShareEmergency(
              app.repository,
            ).share(incident, name, channel, contact),
            success: 'Tentativa registrada. Envio e entrega não confirmados.',
          );
        } finally {
          if (mounted) setState(() => sharing = false);
        }
      }

      return Scaffold(
        appBar: AppHeader(
          title: const Text('Pedir ajuda'),
          leading: IconButton(
            tooltip: 'Voltar ao início',
            icon: const Icon(AppIcons.arrowBack),
            onPressed: () => context.go('/inicio'),
          ),
        ),
        body: OrganizedListView(
          padding: const EdgeInsets.all(24),
          children: [
            SectionHeading(
              'Vamos preparar sua mensagem',
              subtitle: '${incident.label} · ${outcomeLabel(incident.outcome)}',
            ),
            const SizedBox(height: 12),
            const StatusPanel(
              title: 'Você conclui o envio',
              message:
                  'Escolha um contato, confira a mensagem e abra o canal desejado. O ZELO não confirma envio ou entrega.',
              icon: AppIcons.sendOutlined,
            ),
            const SizedBox(height: 16),
            const SectionHeading('1. Escolha quem pode ajudar'),
            for (final person in data.contacts)
              Card(
                color: person.id == contact?.id
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const Icon(AppIcons.personOutlineRounded),
                  title: Text(person.name),
                  subtitle: Text(
                    person.id == data.contacts.first.id
                        ? 'Contato principal'
                        : 'Contato de apoio',
                  ),
                  trailing: Icon(
                    person.id == contact?.id
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                  ),
                  selected: person.id == contact?.id,
                  onTap: sharing
                      ? null
                      : () => setState(() => contactId = person.id),
                ),
              ),
            const SizedBox(height: 16),
            const SectionHeading('2. Confira a mensagem'),
            SectionCard(
              child: SelectableText(
                ShareEmergency.message(incident, name, DateTime.now().toUtc()),
              ),
            ),
            if (data.contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Você ainda não tem contatos cadastrados. Copie a mensagem e escolha o destinatário no aplicativo de sua preferência.',
                ),
              ),
            const SizedBox(height: 20),
            const SectionHeading('3. Escolha o canal'),
            FilledButton.icon(
              onPressed: sharing || contact?.phone == null
                  ? null
                  : () => share('whatsapp'),
              icon: const Icon(AppIcons.chatOutlined),
              label: LoadingLabel(loading: sharing, label: 'Abrir WhatsApp'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: sharing || contact?.email == null
                  ? null
                  : () => share('email'),
              icon: const Icon(AppIcons.emailOutlined),
              label: const Text('Abrir e-mail'),
            ),
            TextButton.icon(
              onPressed: sharing ? null : () => share('copy'),
              icon: const Icon(AppIcons.copy),
              label: const Text('Copiar mensagem'),
            ),
            TextButton(
              onPressed: () =>
                  context.push('/historico/incidents/${incident.id}'),
              child: const Text('Ver registro e atualizar minha condição'),
            ),
          ],
        ),
      );
    },
  );
}
