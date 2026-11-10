import '../presentation/app_icons.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

enum AppTone { neutral, positive, warning, danger }

class ActionFooter extends StatelessWidget {
  const ActionFooter({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class AlertCountdown extends StatelessWidget {
  const AlertCountdown({required this.seconds, super.key});
  final int seconds;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$seconds segundos para responder ao alerta',
    child: ExcludeSemantics(
      child: Center(
        child: SizedBox.square(
          dimension: MediaQuery.textScalerOf(
            context,
          ).scale(100).clamp(180, 280),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: (seconds / 30).clamp(0, 1),
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.emergencyBackground,
                  color: AppTone.danger.foreground,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$seconds',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 44,
                      color: AppTone.danger.foreground,
                    ),
                  ),
                  const Text('segundos'),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

extension AppToneColors on AppTone {
  Color get foreground => switch (this) {
    AppTone.neutral => AppColors.teal,
    AppTone.positive => const Color(0xFF116947),
    AppTone.warning => const Color(0xFF795000),
    AppTone.danger => const Color(0xFFA22435),
  };
  Color get background => switch (this) {
    AppTone.neutral => const Color(0xFFEAF2F5),
    AppTone.positive => AppColors.protectionBackground,
    AppTone.warning => const Color(0xFFFFF3D8),
    AppTone.danger => AppColors.emergencyBackground,
  };
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {this.tone = AppTone.neutral, super.key});
  final IconData icon;
  final AppTone tone;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(icon, color: tone.foreground, size: 24),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {this.subtitle, super.key});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class StatusPanel extends StatelessWidget {
  const StatusPanel({
    required this.title,
    required this.message,
    required this.icon,
    this.tone = AppTone.neutral,
    super.key,
  });
  final String title;
  final String message;
  final IconData icon;
  final AppTone tone;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tone.foreground, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: tone.foreground),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tone.foreground),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AppActionTile extends StatelessWidget {
  const AppActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.external = false,
    super.key,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool external;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: IconBadge(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        external ? AppIcons.openInNewRounded : AppIcons.chevronRightRounded,
        size: 20,
      ),
      onTap: onTap,
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBadge(icon),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class LoadingLabel extends StatelessWidget {
  const LoadingLabel({required this.loading, required this.label, super.key});
  final bool loading;
  final String label;
  @override
  Widget build(BuildContext context) => loading
      ? SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            semanticsLabel: label,
          ),
        )
      : Text(label, textAlign: TextAlign.center);
}

class OrganizedListView extends StatelessWidget {
  const OrganizedListView({
    required this.children,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final groups = <Widget>[];
    var section = <Widget>[];
    void flush() {
      if (section.isEmpty) return;
      groups.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: section,
            ),
          ),
        ),
      );
      section = <Widget>[];
    }

    for (final child in children) {
      if (child is SectionHeading) flush();
      section.add(child);
    }
    flush();
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: padding, children: groups),
        ),
      ),
    );
  }
}
