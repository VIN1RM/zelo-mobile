import 'package:zelo_mobile/core/application/app_controller.dart';
import '../../support/fake_app_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/app/app.dart';
import 'package:zelo_mobile/app/router/app_router.dart';
import 'package:zelo_mobile/features/auth/domain/auth_user.dart';
import 'package:zelo_mobile/features/auth/presentation/providers/auth_providers.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  test(
    'every protected entry rejects signed out, unknown and unverified sessions',
    () {
      for (final path in [
        '/inicio',
        '/contatos',
        '/historico',
        '/ajustes',
        '/ajustes/diagnostico',
        '/ajustes/recursos',
      ]) {
        expect(
          authRedirect(const AsyncData<AuthUser?>(null), path),
          '/boas-vindas',
        );
        expect(
          authRedirect(const AsyncLoading<AuthUser?>(), path),
          '/abertura',
        );
        expect(
          authRedirect(
            AsyncError<AuthUser?>(StateError('test'), StackTrace.empty),
            path,
          ),
          '/abertura',
        );
        expect(
          authRedirect(const AsyncData<AuthUser?>(unverifiedUser), path),
          '/verificar-email',
        );
        expect(
          authRedirect(const AsyncData<AuthUser?>(verifiedUser), path),
          isNull,
        );
      }
    },
  );

  testWidgets(
    'verification opens home; logout removes access even through a direct route',
    (tester) async {
      final repository = FakeAuthRepository(user: unverifiedUser);
      addTearDown(repository.dispose);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          appControllerProvider.overrideWith(FakeAppController.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const ZeloApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verifique seu e-mail'), findsOneWidget);
      expect(find.text('Histórico'), findsNothing);

      repository.emit(verifiedUser);
      await tester.pumpAndSettle();
      expect(find.text('Proteção desativada'), findsOneWidget);

      await repository.signOut();
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/historico');
      await tester.pumpAndSettle();
      expect(find.text('Cuidado em cada caminho.'), findsOneWidget);
      expect(find.text('Histórico'), findsNothing);
      await tester.pumpWidget(const ProviderScope(child: SizedBox()));
    },
  );
}
