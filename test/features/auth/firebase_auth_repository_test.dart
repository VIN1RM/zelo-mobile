import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/features/auth/data/firebase_auth_repository.dart';
import 'package:zelo_mobile/features/auth/domain/auth_failure.dart';

class _User extends Fake implements User {
  final calls = <String>[];

  @override
  Future<void> reload() async => calls.add('reload');

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    calls.add('token:$forceRefresh');
    return 'test-token';
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    calls.add('verify');
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth({this.user, this.failure});

  final User? user;
  final String? failure;
  bool signedOut = false;

  @override
  Future<void> signOut() async => signedOut = true;

  @override
  User? get currentUser => user;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    if (failure != null) {
      throw FirebaseAuthException(
        code: failure!,
        message: 'Internal details must not reach UI',
      );
    }
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw FirebaseAuthException(
      code: failure ?? 'invalid-credential',
      message: 'Internal details must not reach UI',
    );
  }
}

void main() {
  test('detected invalid or disabled session is signed out', () async {
    final auth = _Auth(failure: 'user-disabled');
    await expectLater(
      FirebaseAuthRepository(auth).signIn('rider@example.com', 'password'),
      throwsA(isA<AuthFailure>()),
    );
    expect(auth.signedOut, isTrue);
  });
  test(
    'refresh reloads the user and forces renewal of verification claims',
    () async {
      final user = _User();
      await FirebaseAuthRepository(_Auth(user: user)).refreshUser();
      expect(user.calls, ['reload', 'token:true']);
    },
  );

  test('verification requires a real signed-in SDK user', () async {
    await expectLater(
      FirebaseAuthRepository(_Auth()).sendVerification(),
      throwsA(isA<AuthFailure>()),
    );
    final user = _User();
    await FirebaseAuthRepository(_Auth(user: user)).sendVerification();
    expect(user.calls, ['verify']);
  });

  test(
    'reset feedback does not reveal whether an account exists or is disabled',
    () async {
      for (final code in [null, 'user-not-found', 'user-disabled']) {
        await FirebaseAuthRepository(
          _Auth(failure: code),
        ).sendPasswordReset('rider@example.com');
      }
    },
  );

  test(
    'credential errors share one safe message without SDK internals',
    () async {
      for (final code in [
        'wrong-password',
        'user-not-found',
        'invalid-credential',
      ]) {
        await expectLater(
          FirebaseAuthRepository(
            _Auth(failure: code),
          ).signIn('rider@example.com', 'password'),
          throwsA(
            isA<AuthFailure>().having(
              (error) => error.message,
              'safe message',
              'Não foi possível entrar. Confira o e-mail e a senha.',
            ),
          ),
        );
      }
    },
  );

  test(
    'network failure during reset remains actionable and sanitized',
    () async {
      await expectLater(
        FirebaseAuthRepository(
          _Auth(failure: 'network-request-failed'),
        ).sendPasswordReset('rider@example.com'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'safe message',
            'Sem conexão com o serviço. Verifique a internet e tente novamente.',
          ),
        ),
      );
    },
  );
}
