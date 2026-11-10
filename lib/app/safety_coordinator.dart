import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/application/app_controller.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import 'router/app_router.dart';
import '../features/settings/data/reminder_gateway.dart';

class SafetyCoordinator extends ConsumerStatefulWidget {
  const SafetyCoordinator({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<SafetyCoordinator> createState() => _SafetyCoordinatorState();
}

class _SafetyCoordinatorState extends ConsumerState<SafetyCoordinator>
    with WidgetsBindingObserver {
  final Set<String> _shownHelp = {};
  String? _uid;
  bool _prompted = false;
  bool _remindersInitialized = false;
  Future<void> _activateReminders(String? uid) async {
    try {
      await ref.read(reminderGatewayProvider).activate(uid);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(activeUidProvider) != null) {
      ref.read(appControllerProvider.notifier).resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(
      authUserProvider.select(
        (session) => session.asData?.value?.emailVerified == true
            ? session.asData?.value?.id
            : null,
      ),
    );
    if (!_remindersInitialized || uid != _uid) {
      _remindersInitialized = true;
      _activateReminders(uid);
      _uid = uid;
      _shownHelp.clear();
      _prompted = false;
    }
    if (uid != null) {
      ref.listen(appControllerProvider, (previous, next) {
        final data = next.asData?.value;
        if (data == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || uid != ref.read(activeUidProvider)) return;
          final router = ref.read(appRouterProvider);
          final path = router.routeInformationProvider.value.uri.path;
          if (data.alert != null) {
            final target = '/alerta/${data.alert!.id}';
            if (path != target) router.go(target);
          } else if (data.unresolved != null &&
              previous?.asData?.value.alert?.id == data.unresolved!.id &&
              !_shownHelp.contains(data.unresolved!.id)) {
            _shownHelp.add(data.unresolved!.id);
            final target = '/ajuda/${data.unresolved!.id}';
            if (path != target) router.go(target);
          } else if (path.startsWith('/alerta/')) {
            router.go('/inicio');
          } else if (!data.prepared && !_prompted && path == '/inicio') {
            _prompted = true;
            router.go('/preparar');
          }
        });
      });
    }
    return widget.child;
  }
}
