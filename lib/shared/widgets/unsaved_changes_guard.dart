import 'package:flutter/material.dart';
import 'app_view.dart';

class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    required this.controllers,
    required this.child,
    super.key,
  });
  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<UnsavedChangesGuard> createState() => UnsavedChangesGuardState();
}

class UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  late List<String> _saved;
  bool _dirty = false;
  bool _prompting = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.controllers.map((controller) => controller.text).toList();
    for (final controller in widget.controllers) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    final dirty = widget.controllers.asMap().entries.any(
      (entry) => entry.value.text != _saved[entry.key],
    );
    if (dirty != _dirty && mounted) setState(() => _dirty = dirty);
  }

  Future<void> acceptChanges() async {
    _saved = widget.controllers.map((controller) => controller.text).toList();
    if (mounted) setState(() => _dirty = false);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _attemptExit() async {
    if (_prompting || _leaving) return;
    _prompting = true;
    final leave = await confirmAction(
      context,
      'Descartar alterações?',
      'Você tem alterações não salvas. Ao sair, elas serão perdidas.',
      confirmLabel: 'Descartar e sair',
      destructive: true,
    );
    _prompting = false;
    if (!leave || !mounted) return;
    setState(() => _leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.removeListener(_changed);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty || _leaving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _dirty) _attemptExit();
    },
    child: widget.child,
  );
}
