import 'dart:async';

import 'package:zelo_mobile/features/auth/domain/auth_failure.dart';
import 'package:zelo_mobile/features/auth/domain/auth_repository.dart';
import 'package:zelo_mobile/features/auth/domain/auth_user.dart';

const verifiedUser = AuthUser(
  id: 'user-a',
  email: 'rider@example.com',
  name: 'Rider',
  emailVerified: true,
);
const unverifiedUser = AuthUser(
  id: 'user-a',
  email: 'rider@example.com',
  name: 'Rider',
  emailVerified: false,
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? user}) : _currentUser = user;

  AuthUser? _currentUser;
  final _events = StreamController<AuthUser?>.broadcast(sync: true);
  int registrations = 0;
  int verificationRequests = 0;
  int refreshes = 0;
  String? resetEmail;
  bool failVerification = false;
  bool verifyOnRefresh = false;

  @override
  AuthUser? get currentUser => _currentUser;

  void emit(AuthUser? user) {
    _currentUser = user;
    _events.add(user);
  }

  @override
  Stream<AuthUser?> watchUser() async* {
    yield _currentUser;
    yield* _events.stream;
  }

  Future<void> dispose() => _events.close();

  @override
  Future<void> signIn(String email, String password) async =>
      emit(unverifiedUser);

  @override
  Future<void> register(String name, String email, String password) async {
    registrations++;
    emit(
      AuthUser(id: 'user-a', email: email, name: name, emailVerified: false),
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetEmail = email;

  @override
  Future<void> sendVerification() async {
    verificationRequests++;
    if (failVerification) throw const AuthFailure('Falha de conexão no teste.');
  }

  @override
  Future<void> refreshUser() async {
    refreshes++;
    if (verifyOnRefresh) emit(verifiedUser);
  }

  @override
  Future<void> signOut() async => emit(null);
}
