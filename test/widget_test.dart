import 'package:flutter/material.dart';
import 'package:zelo_mobile/core/application/app_controller.dart';
import 'support/fake_app_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/app/app.dart';
import 'package:zelo_mobile/features/auth/presentation/providers/auth_providers.dart';

import 'support/fake_auth_repository.dart';

void main() {
  testWidgets(
    'home and history support enlarged text without layout exceptions',
    (tester) async {
      final repository = FakeAuthRepository(user: verifiedUser);
      addTearDown(repository.dispose);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            appControllerProvider.overrideWith(FakeAppController.new),
          ],
          child: const ZeloApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
    },
  );
  testWidgets('home does not claim active protection without a service', (
    tester,
  ) async {
    final repository = FakeAuthRepository(user: verifiedUser);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          appControllerProvider.overrideWith(FakeAppController.new),
        ],
        child: const ZeloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IN\u00cdCIO'), findsOneWidget);
    expect(find.text('Proteção desativada'), findsOneWidget);
    expect(find.text('Proteção ativa'), findsNothing);
  });

  testWidgets('main navigation opens the history placeholder', (tester) async {
    final repository = FakeAuthRepository(user: verifiedUser);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          appControllerProvider.overrideWith(FakeAppController.new),
        ],
        child: const ZeloApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum registro neste filtro.'), findsOneWidget);
  });
}
