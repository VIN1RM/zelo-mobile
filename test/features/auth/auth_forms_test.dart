import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:zelo_mobile/features/auth/presentation/screens/auth_form_screen.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  testWidgets(
    'focusing or typing in login does not validate untouched fields before submission',
    (tester) async {
      final repository = FakeAuthRepository();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: AuthFormScreen(mode: AuthFormMode.signIn),
          ),
        ),
      );
      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();
      expect(find.text('Informe um e-mail válido.'), findsNothing);
      expect(find.text('Informe sua senha.'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).first,
        'rider@example.com',
      );
      await tester.tap(find.byType(TextFormField).last);
      await tester.pumpAndSettle();
      expect(find.text('Informe sua senha.'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe sua senha.'), findsOneWidget);
      expect(repository.currentUser, isNull);
    },
  );

  testWidgets('reset shows neutral confirmation after request', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: AuthFormScreen(mode: AuthFormMode.resetPassword),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'rider@example.com');
    await tester.tap(find.text('Enviar instruções'));
    await tester.pumpAndSettle();
    expect(repository.resetEmail, 'rider@example.com');
    expect(find.textContaining('Se houver uma conta'), findsOneWidget);
  });

  testWidgets('empty login is validated without starting authentication', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: AuthFormScreen(mode: AuthFormMode.signIn),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
    expect(repository.currentUser, isNull);
  });
}
