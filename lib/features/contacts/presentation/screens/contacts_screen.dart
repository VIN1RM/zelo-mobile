import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/formatting/phone_format.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../domain/emergency_contact.dart';

enum _ContactAction { primary, test, delete }

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  Future<void> _test(BuildContext context, EmergencyContact contact) async {
    if (!await confirmAction(
      context,
      'Testar canal?',
      'Uma mensagem de TESTE será preparada para ${contact.name}. Você confere e decide se deseja enviar.',
    )) {
      return;
    }
    if (!context.mounted) return;
    final text =
        'TESTE DO ZELO — NÃO É UMA EMERGÊNCIA. Este é um teste do contato ${contact.name}.';
    final uri = contact.phone != null
        ? Uri.https('wa.me', contact.phone!.substring(1), {'text': text})
        : Uri(
            scheme: 'mailto',
            path: contact.email,
            query:
                'subject=TESTE%20DO%20ZELO&body=${Uri.encodeComponent(text)}',
          );
    await uiAction(context, () async {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Unavailable');
      }
    });
  }

  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) => Scaffold(
      appBar: AppHeader(
        title: const Text('Contatos'),
        actions: [
          IconButton(
            tooltip: 'Adicionar contato',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: data.busy || data.contacts.length >= 3
                ? null
                : () => context.push('/contatos/novo'),
          ),
        ],
      ),
      body: AppContent(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          buildDefaultDragHandles: false,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(
                'Sua rede de apoio',
                subtitle:
                    '${data.contacts.length} de 3 contatos · O principal aparece primeiro nos pedidos de ajuda.',
              ),
              if (data.contacts.isEmpty)
                AppEmptyState(
                  icon: Icons.people_outline,
                  title: 'Quem pode ajudar você?',
                  message:
                      'Adicione pessoas de confiança para facilitar seus pedidos de ajuda.',
                  action: FilledButton.icon(
                    onPressed: data.busy
                        ? null
                        : () => context.push('/contatos/novo'),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Adicionar contato'),
                  ),
                ),
            ],
          ),
          itemCount: data.contacts.length,
          onReorder: (oldIndex, newIndex) async {
            if (data.busy) return;
            if (newIndex > oldIndex) newIndex--;
            final ids = data.contacts.map((contact) => contact.id).toList();
            ids.insert(newIndex, ids.removeAt(oldIndex));
            await uiAction(
              context,
              () => app.operation(() => app.repository.reorderContacts(ids)),
            );
          },
          footer: data.contacts.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    data.contacts.length == 3
                        ? 'Sua rede está completa. Você pode editar ou substituir os contatos.'
                        : 'Você pode adicionar mais ${3 - data.contacts.length} pessoa(s) de confiança.',
                    textAlign: TextAlign.center,
                  ),
                ),
          itemBuilder: (context, index) {
            final contact = data.contacts[index];
            final primary = index == 0;
            final scheme = Theme.of(context).colorScheme;
            Future<void> choose(_ContactAction action) async {
              if (data.busy) return;
              switch (action) {
                case _ContactAction.primary:
                  await uiAction(
                    context,
                    () => app.operation(
                      () => app.repository.reorderContacts([
                        contact.id,
                        ...data.contacts
                            .where((item) => item.id != contact.id)
                            .map((item) => item.id),
                      ]),
                    ),
                    success: 'Contato principal atualizado.',
                  );
                case _ContactAction.test:
                  await _test(context, contact);
                case _ContactAction.delete:
                  if (await confirmAction(
                        context,
                        'Excluir contato?',
                        '${contact.name} sairá da sua rede de apoio. A exclusão na nuvem será concluída quando houver conexão.',
                      ) &&
                      context.mounted) {
                    await uiAction(
                      context,
                      () => app.operation(
                        () => app.repository.deleteContact(contact.id),
                      ),
                    );
                  }
              }
            }

            return Card(
              key: ValueKey(contact.id),
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: primary
                      ? scheme.primary.withValues(alpha: 0.5)
                      : scheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          child: Text(
                            contact.name.trim().isEmpty
                                ? '?'
                                : contact.name
                                      .trim()
                                      .characters
                                      .first
                                      .toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                primary
                                    ? 'Contato principal'
                                    : 'Contato de apoio',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: primary
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<_ContactAction>(
                          tooltip: 'Opções de ${contact.name}',
                          enabled: !data.busy,
                          onSelected: choose,
                          itemBuilder: (context) => [
                            if (!primary)
                              const PopupMenuItem(
                                value: _ContactAction.primary,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.star_outline_rounded),
                                  title: Text('Tornar principal'),
                                ),
                              ),
                            const PopupMenuItem(
                              value: _ContactAction.delete,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.delete_outline),
                                title: Text('Excluir contato'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (contact.phone != null)
                      _ContactChannel(
                        icon: Icons.chat_outlined,
                        value: formatPhone(contact.phone),
                      ),
                    if (contact.email != null)
                      _ContactChannel(
                        icon: Icons.mail_outline_rounded,
                        value: contact.email!,
                      ),
                    const SizedBox(height: 16),
                    ResponsiveActions(
                      minimumWidth: 120,
                      children: [
                        OutlinedButton.icon(
                          onPressed: data.busy
                              ? null
                              : () => context.push(
                                  '/contatos/${contact.id}/editar',
                                ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar'),
                        ),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          onPressed: data.busy
                              ? null
                              : () => choose(_ContactAction.test),
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Testar canal'),
                        ),
                      ],
                    ),
                    if (data.contacts.length > 1)
                      Align(
                        alignment: Alignment.center,
                        child: ReorderableDragStartListener(
                          index: index,
                          enabled: !data.busy,
                          child: Semantics(
                            label: 'Arrastar para reordenar ${contact.name}',
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _ContactChannel extends StatelessWidget {
  const _ContactChannel({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
