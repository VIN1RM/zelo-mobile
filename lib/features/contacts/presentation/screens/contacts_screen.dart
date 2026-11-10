import '../../../../core/formatting/phone_format.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/widgets/app_view.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) => Scaffold(
      appBar: AppHeader(
        title: const Text('Contatos'),
        actions: [
          IconButton(
            tooltip: 'Adicionar contato',
            onPressed: data.contacts.length >= 3 || data.busy
                ? null
                : () => context.push('/contatos/novo'),
            icon: const Icon(AppIcons.personAddAlt1),
          ),
        ],
      ),
      body: data.contacts.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppEmptyState(
                  icon: AppIcons.peopleOutlineRounded,
                  title: 'Quem pode ajudar você?',
                  message:
                      'Adicione até três pessoas de confiança. Você precisa de pelo menos um contato para iniciar a proteção.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/contatos/novo'),
                    icon: const Icon(AppIcons.personAddAlt1),
                    label: const Text('Adicionar contato'),
                  ),
                ),
              ],
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              header: SectionHeading(
                'Sua rede de apoio',
                subtitle:
                    '${data.contacts.length} de 3 contatos · O primeiro tem prioridade. Pressione e segure um cartão para mudar a ordem.',
              ),
              itemCount: data.contacts.length,
              onReorder: (oldIndex, newIndex) async {
                if (data.busy) return;
                if (newIndex > oldIndex) newIndex--;
                final ids = data.contacts.map((c) => c.id).toList();
                final id = ids.removeAt(oldIndex);
                ids.insert(newIndex, id);
                await uiAction(
                  context,
                  () =>
                      app.operation(() => app.repository.reorderContacts(ids)),
                );
              },
              itemBuilder: (context, index) {
                final contact = data.contacts[index];
                return Card(
                  key: ValueKey(contact.id),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(contact.name),
                          subtitle: Text(
                            '${index == 0 ? 'Contato principal\n' : ''}${formatPhone(contact.phone)}${contact.email == null ? '' : '\n${contact.email}'}',
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (index != 0)
                              OutlinedButton.icon(
                                onPressed: data.busy
                                    ? null
                                    : () => uiAction(
                                        context,
                                        () => app.operation(
                                          () => app.repository.reorderContacts([
                                            contact.id,
                                            ...data.contacts
                                                .where(
                                                  (c) => c.id != contact.id,
                                                )
                                                .map((c) => c.id),
                                          ]),
                                        ),
                                        success:
                                            'Contato principal atualizado.',
                                      ),
                                icon: const Icon(AppIcons.shieldOutlined),
                                label: const Text('Tornar principal'),
                              ),
                            TextButton.icon(
                              onPressed: data.busy
                                  ? null
                                  : () => context.push(
                                      '/contatos/${contact.id}/editar',
                                    ),
                              icon: const Icon(AppIcons.editOutlined),
                              label: const Text('Editar'),
                            ),
                            TextButton.icon(
                              onPressed: data.busy
                                  ? null
                                  : () async {
                                      if (await confirmAction(
                                            context,
                                            'Excluir contato?',
                                            'O contato será ocultado localmente e a exclusão remota ficará pendente até confirmação.',
                                          ) &&
                                          context.mounted) {
                                        await uiAction(
                                          context,
                                          () => app.operation(
                                            () => app.repository.deleteContact(
                                              contact.id,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(AppIcons.deleteOutline),
                              label: const Text('Excluir'),
                            ),
                            TextButton(
                              onPressed: data.busy
                                  ? null
                                  : () async {
                                      if (!await confirmAction(
                                        context,
                                        'Testar canal?',
                                        'Será aberta uma mensagem marcada como TESTE. Você decide se deseja enviá-la.',
                                      )) {
                                        return;
                                      }
                                      final text =
                                          'TESTE DO ZELO — NÃO É UMA EMERGÊNCIA. Este é um teste do contato ${contact.name}.';
                                      final uri = contact.phone != null
                                          ? Uri.https(
                                              'wa.me',
                                              contact.phone!.substring(1),
                                              {'text': text},
                                            )
                                          : Uri(
                                              scheme: 'mailto',
                                              path: contact.email,
                                              query:
                                                  'subject=TESTE%20DO%20ZELO&body=${Uri.encodeComponent(text)}',
                                            );
                                      if (context.mounted) {
                                        await uiAction(context, () async {
                                          if (!await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          )) {
                                            throw Exception('Unavailable');
                                          }
                                        });
                                      }
                                    },
                              child: const Text('Testar canal'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    ),
  );
}
