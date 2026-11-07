import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/app/app.dart';
import 'package:zelo_mobile/features/auth/presentation/providers/auth_providers.dart';

import 'support/fake_auth_repository.dart';

void main() {
  testWidgets('home clearly states that protection is not available yet', (
    tester,
  ) async {
    final repository = FakeAuthRepository(user: verifiedUser);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const ZeloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ZELO'), findsOneWidget);
    expect(find.text('O ZELO ainda está sendo preparado'), findsOneWidget);
    expect(
      find.textContaining('O aplicativo ainda não monitora trajetos'),
      findsOneWidget,
    );
  });

  testWidgets('main navigation opens the history placeholder', (tester) async {
    final repository = FakeAuthRepository(user: verifiedUser);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const ZeloApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Trajetos e ocorrências ainda não são registrados pelo aplicativo.',
      ),
      findsOneWidget,
    );
  });
}
