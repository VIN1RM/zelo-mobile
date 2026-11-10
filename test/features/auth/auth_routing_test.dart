import 'package:zelo_mobile/features/emergency/domain/incident.dart';
import 'dart:async';
import 'package:zelo_mobile/features/contacts/domain/emergency_contact.dart';
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

class _PendingHelpController extends FakeAppController {
  @override
  Future<AppSnapshot> build() async => AppSnapshot(
    prepared: true,
    incidents: [
      Incident(
        id: 'old-incident',
        type: 'SOS',
        occurredAt: DateTime.utc(2026),
        outcome: 'HELP_REQUESTED',
        condition: 'NEEDS_HELP',
        preserved: true,
      ),
    ],
  );
}

class _RestoringController extends FakeAppController {
  _RestoringController(this.restored);
  final Future<AppSnapshot> restored;
  @override
  Future<AppSnapshot> build() => restored;
}

void main() {
  testWidgets('restored contacts arrive before onboarding is considered', (
    tester,
  ) async {
    final auth = FakeAuthRepository(user: verifiedUser);
    addTearDown(auth.dispose);
    final ready = Completer<AppSnapshot>();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        appControllerProvider.overrideWith(
          () => _RestoringController(ready.future),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ZeloApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/inicio',
    );
    expect(find.text('Carregando sua conta e contatos…'), findsOneWidget);
    ready.complete(
      const AppSnapshot(
        remoteDataLoaded: true,
        contacts: [
          EmergencyContact(
            id: 'a',
            name: 'Ana',
            priority: 1,
            phone: '+5511999999999',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/inicio',
    );
    await tester.scrollUntilVisible(
      find.text('1 de 3 contatos cadastrados'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 de 3 contatos cadastrados'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('login keeps home open when an old request remains unresolved', (
    tester,
  ) async {
    final repository = FakeAuthRepository(user: verifiedUser);
    addTearDown(repository.dispose);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        appControllerProvider.overrideWith(_PendingHelpController.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ZeloApp()),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/inicio',
    );
    await tester.pumpWidget(const SizedBox());
  });

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
        '/licencas',
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
