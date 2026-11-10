import '../../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../../core/formatting/phone_format.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../../core/domain/app_failure.dart';
import '../../domain/emergency_contact.dart';

class ContactFormScreen extends StatefulWidget {
  const ContactFormScreen({this.id, super.key});
  final String? id;
  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _guard = GlobalKey<UnsavedChangesGuardState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  bool initialized = false;
  int? expectedRevision;
  final formKey = GlobalKey<FormState>();
  bool submitted = false;
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
        phone.text = formatPhone(contact?.phone);
        email.text = contact?.email ?? '';
        expectedRevision = contact?.revision;
        initialized = true;
      }
      return UnsavedChangesGuard(
        key: _guard,
        controllers: [name, phone, email],
        child: Scaffold(
          appBar: AppHeader(
            title: Text(widget.id == null ? 'Novo contato' : 'Editar contato'),
          ),
          body: AppContent(
            child: Form(
              key: formKey,
              autovalidateMode: submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeading(
                      widget.id == null
                          ? 'Adicione alguém de confiança'
                          : 'Mantenha o contato atualizado',
                      subtitle:
                          'Informe um número de WhatsApp ou e-mail para preparar seus pedidos de ajuda.',
                    ),
                    TextFormField(
                      controller: name,
                      validator: (value) =>
                          EmergencyContact.nameError(value ?? ''),
                      textInputAction: TextInputAction.next,
                      enabled: !data.busy,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Nome do contato',
                        prefixIcon: Icon(AppIcons.personOutline),
                        errorMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phone,
                      inputFormatters: [PhoneInputFormatter()],
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty &&
                            email.text.trim().isEmpty) {
                          return 'Informe um WhatsApp ou preencha o e-mail abaixo.';
                        }
                        try {
                          EmergencyContact.normalizePhone(value ?? '');
                          return null;
                        } on AppFailure catch (error) {
                          return error.message;
                        }
                      },
                      enabled: !data.busy,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp',
                        prefixIcon: Icon(AppIcons.chatOutlined),
                        hintText: '+55 (11) 99999-9999',
                        helperText: 'Inclua +, código do país e DDD.',
                        helperMaxLines: 3,
                        errorMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: email,
                      validator: (value) => EmergencyContact.emailError(
                        (value ?? '').trim().isEmpty ? null : value!.trim(),
                      ),
                      textInputAction: TextInputAction.done,
                      enabled: !data.busy,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(AppIcons.emailOutlined),
                        errorMaxLines: 3,
                      ),
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
                              setState(() => submitted = true);
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              FocusScope.of(context).unfocus();
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
                              if (saved) {
                                await _guard.currentState?.acceptChanges();
                              }
                              if (saved && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      child: LoadingLabel(
                        loading: data.busy,
                        label: 'Salvar contato',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
