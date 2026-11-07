import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_validation.dart';

class AuthActions {
  AuthActions(this.repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AuthRepository repository;
  final DateTime Function() _now;
  final Map<String, DateTime> _verificationSentAt = {};

  void _validate(String? message) {
    if (message != null) throw AuthFailure(message);
  }

  Future<void> signIn(String email, String password) async {
    _validate(AuthValidation.email(email));
    _validate(AuthValidation.signInPassword(password));
    await repository.signIn(email.trim(), password);
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String confirmation,
  ) async {
    _validate(AuthValidation.name(name));
    _validate(AuthValidation.email(email));
    _validate(AuthValidation.password(password));
    _validate(AuthValidation.confirmation(confirmation, password));
    await repository.register(name.trim(), email.trim(), password);
    await sendVerification();
  }

  Future<void> resetPassword(String email) async {
    _validate(AuthValidation.email(email));
    await repository.sendPasswordReset(email.trim());
  }

  int get resendWaitSeconds {
    final last = _verificationSentAt[repository.currentUser?.id];
    if (last == null) return 0;
    final milliseconds = last
        .add(const Duration(seconds: 60))
        .difference(_now())
        .inMilliseconds;
    return milliseconds > 0 ? (milliseconds / 1000).ceil() : 0;
  }

  Future<void> sendVerification() async {
    final user = repository.currentUser;
    if (user == null) {
      throw const AuthFailure('Entre novamente para continuar.');
    }
    if (resendWaitSeconds > 0) {
      throw const AuthFailure('Aguarde antes de reenviar a verificação.');
    }
    await repository.sendVerification();
    _verificationSentAt[user.id] = _now();
  }

  Future<void> checkVerification() async {
    await repository.refreshUser();
    if (repository.currentUser?.emailVerified != true) {
      throw const AuthFailure(
        'Seu e-mail ainda não foi verificado. Confira a caixa de entrada e o spam.',
      );
    }
  }
}
