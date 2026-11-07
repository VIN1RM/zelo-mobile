import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_view.dart';

class ContactFormScreen extends StatefulWidget {
  const ContactFormScreen({this.id, super.key});
  final String? id;
  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  bool initialized = false;
  int? expectedRevision;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      if (!initialized) {
        final contact = data.contacts
            .where((c) => c.id == widget.id)
            .firstOrNull;
        name.text = contact?.name ?? '';
        phone.text = contact?.phone ?? '';
        email.text = contact?.email ?? '';
        expectedRevision = contact?.revision;
        initialized = true;
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.id == null ? 'Novo contato' : 'Editar contato'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: name,
              enabled: !data.busy,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phone,
              enabled: !data.busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                hintText: '+5511999999999',
                helperText: 'Inclua +, código do país e DDD.',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: email,
              enabled: !data.busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Informe pelo menos um canal. Não é necessário permitir acesso à agenda do telefone.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: data.busy
                  ? null
                  : () async {
                      final saved = await uiAction(
                        context,
                        () => app.operation(
                          () => app.repository.saveContact(
                            id: widget.id,
                            expectedRevision: expectedRevision,
                            name: name.text,
                            phone: phone.text,
                            email: email.text,
                          ),
                        ),
                      );
                      if (saved && context.mounted) Navigator.pop(context);
                    },
              child: Text(data.busy ? 'Salvando…' : 'Salvar contato'),
            ),
          ],
        ),
      );
    },
  );
}
