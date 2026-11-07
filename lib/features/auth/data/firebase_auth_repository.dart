import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  AuthUser? _map(User? user) => user == null
      ? null
      : AuthUser(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
          emailVerified: user.emailVerified,
        );

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> watchUser() => _auth.userChanges().map(_map);

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      if (const {
        'user-disabled',
        'user-token-expired',
        'invalid-user-token',
      }.contains(error.code)) {
        await _auth.signOut();
      }
      throw AuthFailure(switch (error.code) {
        'network-request-failed' =>
          'Sem conexão com o serviço. Verifique a internet e tente novamente.',
        'too-many-requests' =>
          'Muitas tentativas. Aguarde um pouco antes de tentar novamente.',
        'weak-password' || 'password-does-not-meet-requirements' =>
          'Escolha uma senha que atenda aos critérios.',
        'invalid-email' => 'Informe um e-mail válido.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'Não foi possível entrar. Confira o e-mail e a senha.',
        'email-already-in-use' =>
          'Não foi possível criar a conta. Tente entrar ou recuperar sua senha.',
        'user-disabled' || 'user-token-expired' || 'invalid-user-token' =>
          'A sessão não está disponível. Saia e tente entrar novamente.',
        _ => 'Não foi possível concluir. Tente novamente em instantes.',
      });
    }
  }

  @override
  Future<void> signIn(String email, String password) => _run(() async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  });

  @override
  Future<void> register(String name, String email, String password) =>
      _run(() async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await credential.user!.updateDisplayName(name);
      });

  @override
  Future<void> sendPasswordReset(String email) => _run(() async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      // A missing or disabled account must receive the same neutral feedback.
      if (error.code != 'user-not-found' && error.code != 'user-disabled') {
        rethrow;
      }
    }
  });

  User _requireUser() =>
      _auth.currentUser ??
      (throw const AuthFailure('Entre novamente para continuar.'));

  @override
  Future<void> sendVerification() =>
      _run(() => _requireUser().sendEmailVerification());

  @override
  Future<void> refreshUser() => _run(() async {
    try {
      await _requireUser().reload();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') await _auth.signOut();
      rethrow;
    }
    await _requireUser().getIdToken(true);
  });

  @override
  Future<void> signOut() => _run(_auth.signOut);
}
