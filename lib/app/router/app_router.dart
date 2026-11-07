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
import '../../features/contacts/presentation/screens/contact_form_screen.dart';
import '../../features/emergency/presentation/screens/emergency_screens.dart';
import '../../features/history/presentation/screens/record_details_screen.dart';
import '../../features/onboarding/presentation/screens/preparation_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/demo_screen.dart';
import '../../features/settings/presentation/screens/sync_screen.dart';
import '../../features/settings/presentation/screens/privacy_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/settings/presentation/screens/device_diagnostics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'app_shell.dart';
import '../../features/device_resources/presentation/screens/device_resources_screen.dart';

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
        path: '/ajustes/recursos',
        builder: (context, state) => const DeviceResourcesScreen(),
      ),
      GoRoute(
        path: '/preparar',
        builder: (context, state) => const PreparationScreen(),
      ),
      GoRoute(
        path: '/alerta/:id',
        builder: (context, state) =>
            AlertScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/ajuda/:id',
        builder: (context, state) =>
            HelpScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/historico/:type/:id',
        builder: (context, state) => RecordDetailsScreen(
          type: state.pathParameters['type']!,
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/contatos/novo',
        builder: (context, state) => const ContactFormScreen(),
      ),
      GoRoute(
        path: '/contatos/:id/editar',
        builder: (context, state) =>
            ContactFormScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/conta',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/demonstracao',
        builder: (context, state) => const DemoScreen(),
      ),
      GoRoute(
        path: '/sincronizacao',
        builder: (context, state) => const SyncScreen(),
      ),
      GoRoute(
        path: '/privacidade',
        builder: (context, state) => const PrivacyScreen(),
      ),
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
