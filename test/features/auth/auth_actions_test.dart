import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/features/auth/application/auth_actions.dart';
import 'package:zelo_mobile/features/auth/domain/auth_failure.dart';
import 'package:zelo_mobile/features/auth/domain/auth_user.dart';
import 'package:zelo_mobile/features/auth/domain/auth_validation.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  test('password requires all five criteria and confirmation', () {
    for (final password in [
      'Abc1!',
      'abcdefgh1!',
      'ABCDEFGH1!',
      'Abcdefgh!',
      'Abcdefgh1',
      'Abcdefgh1 ',
    ]) {
      expect(AuthValidation.password(password), isNotNull, reason: password);
    }
    expect(AuthValidation.password('Abcdefgh1!'), isNull);
    expect(AuthValidation.confirmation('Abcdefgh2!', 'Abcdefgh1!'), isNotNull);
  });

  test('invalid registration never reaches the repository', () async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    final actions = AuthActions(repository);
    await expectLater(
      actions.register('Rider', 'bad', 'Abcdefgh1!', 'Abcdefgh1!'),
      throwsA(isA<AuthFailure>()),
    );
    await expectLater(
      actions.register('Rider', 'a@example.com', 'weak', 'weak'),
      throwsA(isA<AuthFailure>()),
    );
    await expectLater(
      actions.register('Rider', 'a@example.com', 'Abcdefgh1!', 'different'),
      throwsA(isA<AuthFailure>()),
    );
    expect(repository.registrations, 0);
  });

  test('registration normalizes fields and requests verification', () async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    final actions = AuthActions(repository);
    await actions.register(
      ' Rider ',
      ' rider@example.com ',
      'Abcdefgh1!',
      'Abcdefgh1!',
    );
    expect(repository.currentUser?.name, 'Rider');
    expect(repository.currentUser?.email, 'rider@example.com');
    expect(repository.currentUser?.emailVerified, isFalse);
    expect(repository.verificationRequests, 1);
    expect(actions.resendWaitSeconds, 60);
  });

  test(
    'resend waits sixty seconds and does not throttle another UID',
    () async {
      final repository = FakeAuthRepository(user: unverifiedUser);
      addTearDown(repository.dispose);
      var now = DateTime.utc(2026);
      final actions = AuthActions(repository, now: () => now);
      await actions.sendVerification();
      await expectLater(
        actions.sendVerification(),
        throwsA(isA<AuthFailure>()),
      );
      now = now.add(const Duration(seconds: 59));
      expect(actions.resendWaitSeconds, 1);
      now = now.add(const Duration(seconds: 1));
      await actions.sendVerification();
      repository.emit(
        const AuthUser(
          id: 'user-b',
          email: 'b@example.com',
          name: 'B',
          emailVerified: false,
        ),
      );
      expect(actions.resendWaitSeconds, 0);
      expect(repository.verificationRequests, 2);
    },
  );

  test('failed verification send keeps the account and allows retry', () async {
    final repository = FakeAuthRepository()..failVerification = true;
    addTearDown(repository.dispose);
    final actions = AuthActions(repository);
    await expectLater(
      actions.register(
        'Rider',
        'rider@example.com',
        'Abcdefgh1!',
        'Abcdefgh1!',
      ),
      throwsA(isA<AuthFailure>()),
    );
    expect(repository.currentUser, isNotNull);
    expect(actions.resendWaitSeconds, 0);
    repository.failVerification = false;
    await actions.sendVerification();
    expect(repository.registrations, 1);
  });

  test(
    'verification checks the repository and never accepts a local button alone',
    () async {
      final repository = FakeAuthRepository(user: unverifiedUser);
      addTearDown(repository.dispose);
      final actions = AuthActions(repository);
      await expectLater(
        actions.checkVerification(),
        throwsA(isA<AuthFailure>()),
      );
      repository.verifyOnRefresh = true;
      await actions.checkVerification();
      expect(repository.refreshes, 2);
    },
  );
}
