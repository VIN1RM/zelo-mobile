import 'auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> watchUser();
  Future<void> signIn(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> sendVerification();
  Future<void> refreshUser();
  Future<void> signOut();
}
