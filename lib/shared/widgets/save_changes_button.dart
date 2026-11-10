import 'package:flutter/material.dart';
import 'app_components.dart';
import 'unsaved_changes_guard.dart';

class SaveChangesButton extends StatelessWidget {
  const SaveChangesButton({
    required this.guard,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.outlined = false,
    super.key,
  });
  final GlobalKey<UnsavedChangesGuardState> guard;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    Widget button(bool changed) {
      final action = changed && !busy ? onPressed : null;
      final child = LoadingLabel(loading: busy, label: label);
      return outlined
          ? OutlinedButton(onPressed: action, child: child)
          : FilledButton(onPressed: action, child: child);
    }

    final state = guard.currentState;
    if (state == null) return button(false);
    return ValueListenableBuilder<bool>(
      valueListenable: state.changes,
      builder: (context, changed, child) => button(changed),
    );
  }
}
