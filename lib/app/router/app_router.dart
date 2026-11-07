import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/auth_form_screen.dart';
import '../../features/auth/presentation/screens/session_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/settings/presentation/screens/device_diagnostics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'app_shell.dart';

const _publicPaths = {
  '/boas-vindas',
  '/entrar',
  '/criar-conta',
  '/recuperar-senha',
};

String? authRedirect(AsyncValue<AuthUser?> session, String path) {
  if (session.isLoading || session.hasError) {
    return path == '/abertura' ? null : '/abertura';
  }
  final user = session.asData?.value;
  if (user == null) return _publicPaths.contains(path) ? null : '/boas-vindas';
  if (!user.emailVerified) {
    return path == '/verificar-email' ? null : '/verificar-email';
  }
  return _publicPaths.contains(path) ||
          path == '/abertura' ||
          path == '/verificar-email'
      ? '/inicio'
      : null;
}

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authUserProvider, (previous, next) => refresh.refresh());
  final router = GoRouter(
    initialLocation: '/abertura',
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authUserProvider), state.uri.path),
    routes: [
      GoRoute(
        path: '/abertura',
        builder: (context, state) => const SessionScreen(),
      ),
      GoRoute(
        path: '/boas-vindas',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/entrar',
        builder: (context, state) =>
            const AuthFormScreen(mode: AuthFormMode.signIn),
      ),
      GoRoute(
        path: '/criar-conta',
        builder: (context, state) =>
            const AuthFormScreen(mode: AuthFormMode.register),
      ),
      GoRoute(
        path: '/recuperar-senha',
        builder: (context, state) =>
            const AuthFormScreen(mode: AuthFormMode.resetPassword),
      ),
      GoRoute(
        path: '/verificar-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inicio',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contatos',
                builder: (context, state) => const ContactsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/historico',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ajustes',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'diagnostico',
                    builder: (context, state) =>
                        const DeviceDiagnosticsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
