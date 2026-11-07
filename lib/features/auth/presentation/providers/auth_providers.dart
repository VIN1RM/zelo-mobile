import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_actions.dart';
import '../../data/firebase_auth_repository.dart';
import '../../domain/auth_failure.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance),
);

final authUserProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
  retry: (count, error) => null,
);

final authActionsProvider = Provider<AuthActions>(
  (ref) => AuthActions(ref.watch(authRepositoryProvider)),
);

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> run(Future<void> Function(AuthActions actions) action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action(ref.read(authActionsProvider));
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(
        error is AuthFailure
            ? error
            : const AuthFailure('Não foi possível concluir. Tente novamente.'),
        stack,
      );
      return false;
    }
  }

  void clearError() {
    if (!state.isLoading) state = const AsyncData(null);
  }
}
