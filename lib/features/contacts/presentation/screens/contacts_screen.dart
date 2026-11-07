import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/widgets/app_view.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) => Scaffold(
      appBar: AppBar(
        title: const Text('Contatos'),
        actions: [
          IconButton(
            tooltip: 'Adicionar contato',
            onPressed: data.contacts.length >= 3 || data.busy
                ? null
                : () => context.push('/contatos/novo'),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: data.contacts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cadastre pelo menos um contato para iniciar a proteção. Você pode ter até três.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/contatos/novo'),
                      child: const Text('Adicionar contato'),
                    ),
                  ],
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.contacts.length,
              onReorder: (oldIndex, newIndex) async {
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
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(contact.name),
                          subtitle: Text(
                            '${index == 0 ? 'Contato principal\n' : ''}${contact.phone ?? ''}${contact.email == null ? '' : '\n${contact.email}'}',
                          ),
                        ),
                        Wrap(
                          children: [
                            TextButton.icon(
                              onPressed: data.busy
                                  ? null
                                  : () => context.push(
                                      '/contatos/${contact.id}/editar',
                                    ),
                              icon: const Icon(Icons.edit_outlined),
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
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Excluir'),
                            ),
                            TextButton(
                              onPressed: () async {
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
                                      mode: LaunchMode.externalApplication,
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
