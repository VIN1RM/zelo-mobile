import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../../core/formatting/phone_format.dart';
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
          body: AppContent(
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
  String? sharingChannel;
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
        if (sharing) return;
        setState(() {
          sharing = true;
          sharingChannel = channel;
        });
        try {
          await uiAction(
            context,
            () => ShareEmergency(
              app.repository,
            ).share(incident, name, channel, contact),
            success: channel == 'copy'
                ? 'Mensagem copiada. Cole no aplicativo de sua preferência.'
                : 'Canal aberto. Confira a mensagem e conclua o envio.',
          );
        } finally {
          if (mounted) {
            setState(() {
              sharing = false;
              sharingChannel = null;
            });
          }
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
            if (data.contacts.isEmpty)
              AppEmptyState(
                icon: AppIcons.peopleOutlineRounded,
                title: 'Sua rede de apoio começa aqui',
                message:
                    'Adicione uma pessoa de confiança ou copie a mensagem para escolher um destinatário em outro aplicativo.',
                action: OutlinedButton(
                  onPressed: sharing
                      ? null
                      : () => context.push('/contatos/novo'),
                  child: const Text('Adicionar contato'),
                ),
              ),
            for (final person in data.contacts)
              Card(
                clipBehavior: Clip.antiAlias,
                color: person.id == contact?.id
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: ContactAvatar(contact: person, radius: 20),
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
            Text(
              contact == null
                  ? 'Copie a mensagem e escolha o destinatário no seu aplicativo.'
                  : 'Escolha como enviar para ${contact.name}. Confira o conteúdo antes de concluir.',
            ),
            const SizedBox(height: 12),
            _ShareChannelCard(
              title: 'Abrir WhatsApp',
              icon: Icons.chat_outlined,
              subtitle: contact?.phone == null
                  ? 'Este contato não tem WhatsApp cadastrado.'
                  : formatPhone(contact!.phone),
              available: contact?.phone != null,
              loading: sharingChannel == 'whatsapp',
              onPressed: sharing || contact?.phone == null
                  ? null
                  : () => share('whatsapp'),
            ),
            _ShareChannelCard(
              title: 'Abrir e-mail',
              icon: Icons.mail_outline_rounded,
              subtitle:
                  contact?.email ?? 'Este contato não tem e-mail cadastrado.',
              available: contact?.email != null,
              loading: sharingChannel == 'email',
              onPressed: sharing || contact?.email == null
                  ? null
                  : () => share('email'),
            ),
            _ShareChannelCard(
              title: 'Copiar mensagem',
              icon: Icons.copy_rounded,
              subtitle: 'Cole no aplicativo de sua preferência.',
              available: true,
              loading: sharingChannel == 'copy',
              onPressed: sharing ? null : () => share('copy'),
            ),
            const SizedBox(height: 8),
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

class _ShareChannelCard extends StatelessWidget {
  const _ShareChannelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.available,
    required this.loading,
    required this.onPressed,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool available;
  final bool loading;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      enabled: available,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onPressed,
      trailing: loading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              available
                  ? Icons.arrow_forward_rounded
                  : Icons.lock_outline_rounded,
              size: 20,
            ),
    ),
  );
}
