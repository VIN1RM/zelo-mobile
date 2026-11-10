import '../../../../shared/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/auth_validation.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_layout.dart';

enum AuthFormMode { signIn, register, resetPassword }

class AuthFormScreen extends ConsumerStatefulWidget {
  const AuthFormScreen({required this.mode, super.key});

  final AuthFormMode mode;

  @override
  ConsumerState<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends ConsumerState<AuthFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _resetRequested = false;

  bool get _register => widget.mode == AuthFormMode.register;
  bool get _reset => widget.mode == AuthFormMode.resetPassword;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _navigate(String path) {
    ref.read(authControllerProvider.notifier).clearError();
    context.go(path);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await ref
        .read(authControllerProvider.notifier)
        .run(
          (actions) => switch (widget.mode) {
            AuthFormMode.signIn => actions.signIn(_email.text, _password.text),
            AuthFormMode.register => actions.register(
              _name.text,
              _email.text,
              _password.text,
              _confirmation.text,
            ),
            AuthFormMode.resetPassword => actions.resetPassword(_email.text),
          },
        );
    if (mounted && success && _reset) setState(() => _resetRequested = true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    final title = _register
        ? 'Criar conta'
        : _reset
        ? 'Recuperar senha'
        : 'Entrar';
    return AuthLayout(
      title: title,
      children: [
        Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_register) ...[
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: AuthValidation.name,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _email,
                  textInputAction: _reset
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onFieldSubmitted: _reset && !busy && !_resetRequested
                      ? (_) => _submit()
                      : null,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: AuthValidation.email,
                ),
                if (!_reset) ...[
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    label: 'Senha',
                    enabled: !busy,
                    newPassword: _register,
                    validator: _register
                        ? AuthValidation.password
                        : AuthValidation.signInPassword,
                    onChanged: _register ? (_) => setState(() {}) : null,
                  ),
                ],
                if (_register) ...[
                  const SizedBox(height: 12),
                  for (final criterion in AuthValidation.passwordCriteria(
                    _password.text,
                  ).entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${criterion.value ? '✓' : '○'} ${criterion.key}',
                      ),
                    ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _confirmation,
                    label: 'Confirmar senha',
                    enabled: !busy,
                    newPassword: true,
                    validator: (value) =>
                        AuthValidation.confirmation(value, _password.text),
                  ),
                ],
                const SizedBox(height: 20),
                const AuthFeedback(),
                if (_resetRequested) ...[
                  Semantics(
                    liveRegion: true,
                    child: const Text(
                      'Se houver uma conta para esse e-mail, você receberá instruções para redefinir a senha. Confira também o spam.',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: busy || _resetRequested ? null : _submit,
                  child: LoadingLabel(
                    loading: busy,
                    label: _reset ? 'Enviar instruções' : title,
                  ),
                ),
                if (!_register && !_reset)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _navigate('/recuperar-senha'),
                    child: const Text('Esqueci minha senha'),
                  ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _navigate(
                          _register || _reset ? '/entrar' : '/criar-conta',
                        ),
                  child: Text(
                    _register || _reset
                        ? 'Voltar para entrar'
                        : 'Criar uma conta',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
