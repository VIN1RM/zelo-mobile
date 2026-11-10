import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/zelo_logo.dart';
import '../../../../shared/widgets/app_components.dart';
import '../providers/auth_providers.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.children,
    this.headerTitle,
    super.key,
  });

  final String title;
  final String? headerTitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppHeader(title: Text(headerTitle ?? title)),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: ZeloLogo()),
              const SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class AuthFeedback extends ConsumerWidget {
  const AuthFeedback({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    if (!state.hasError) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: StatusPanel(
          title: 'Vamos tentar novamente',
          message: state.error.toString(),
          icon: AppIcons.infoOutlineRounded,
          tone: AppTone.warning,
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    required this.validator,
    required this.enabled,
    this.onChanged,
    this.newPassword = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final bool enabled;
  final bool newPassword;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _obscure,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    validator: widget.validator,
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        onPressed: widget.enabled
            ? () => setState(() => _obscure = !_obscure)
            : null,
        tooltip: _obscure
            ? 'Mostrar ${widget.label.toLowerCase()}'
            : 'Ocultar ${widget.label.toLowerCase()}',
        icon: Icon(
          _obscure
              ? AppIcons.visibilityOutlined
              : AppIcons.visibilityOffOutlined,
        ),
      ),
    ),
  );
}
