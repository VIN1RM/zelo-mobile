import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    super.key,
  });
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  @override
  Size get preferredSize => const Size.fromHeight(72);
  @override
  Widget build(BuildContext context) {
    final label = title is Text ? (title as Text).data ?? '' : '';
    return AppBar(
      toolbarHeight: 72,
      centerTitle: true,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      title: label.isEmpty
          ? title
          : Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                height: 1.2,
              ),
            ),
    );
  }
}
