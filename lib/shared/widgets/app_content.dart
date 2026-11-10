import 'package:flutter/material.dart';

/// Largura de leitura comum, sem esconder o conteúdo atrás do sistema.
class AppContent extends StatelessWidget {
  const AppContent({required this.child, this.maxWidth = 680, super.key});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}

class AppScrollView extends StatelessWidget {
  const AppScrollView({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
    super.key,
  });
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => AppContent(
    child: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: padding,
      children: children,
    ),
  );
}
