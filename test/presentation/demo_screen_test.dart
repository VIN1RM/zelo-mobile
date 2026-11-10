import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zelo_mobile/app/theme/app_theme.dart';
import 'package:zelo_mobile/core/application/app_controller.dart';
import 'package:zelo_mobile/features/emergency/domain/incident.dart';
import 'package:zelo_mobile/features/settings/presentation/screens/demo_screen.dart';

class _DemoApp extends AppController {
  _DemoApp(this.snapshot);
  final AppSnapshot snapshot;

  @override
  Future<AppSnapshot> build() async => snapshot;

  void emitSnapshot(AppSnapshot value) => state = AsyncData(value);
}

Incident _incident(String outcome) => Incident(
  id: 'old-incident',
  type: 'POSSIBLE_ACCIDENT',
  occurredAt: DateTime.utc(2025),
  outcome: outcome,
  condition: 'UNKNOWN',
  preserved: false,
);

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  AppSnapshot snapshot = const AppSnapshot(),
  DateTime Function() now = DateTime.now,
  bool dark = false,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [appControllerProvider.overrideWith(() => _DemoApp(snapshot))],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/demo',
    routes: [
      GoRoute(
        path: '/demo',
        builder: (_, _) => DemoScreen(now: now),
      ),
      GoRoute(
        path: '/inicio',
        builder: (_, _) => const Scaffold(body: Text('Início de teste')),
      ),
      GoRoute(
        path: '/historico/incidents/:id',
        builder: (_, _) => const Scaffold(body: Text('Registro de teste')),
      ),
      GoRoute(
        path: '/alerta/:id',
        builder: (_, _) => const Scaffold(body: Text('Alerta real de teste')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'old unresolved incident allows simulation and links to its record',
    (tester) async {
      await _mount(
        tester,
        snapshot: AppSnapshot(incidents: [_incident('TIMED_OUT')]),
      );
      expect(find.text('Imagine este cenário'), findsOneWidget);
      await _tap(tester, 'Revisar ocorrência');
      await tester.pumpAndSettle();
      expect(find.text('Registro de teste'), findsOneWidget);
    },
  );

  testWidgets(
    'safe response, replay, help preview and completion stay simulated',
    (tester) async {
      final container = await _mount(tester);
      await _tap(tester, 'Iniciar simulação');
      expect(find.text('Você está bem?'), findsOneWidget);
      await _tap(tester, 'Estou bem');
      expect(find.text('Alerta simulado cancelado'), findsOneWidget);
      await _tap(tester, 'Experimentar outra resposta');
      await _tap(tester, 'Preciso de ajuda');
      expect(find.text('Ajuda simulada preparada'), findsOneWidget);
      await tester.ensureVisible(find.text('PRÉVIA FICTÍCIA'));
      expect(find.text('Para: Contato de exemplo'), findsOneWidget);
      expect(
        container.read(appControllerProvider).requireValue.incidents,
        isEmpty,
      );
      expect(
        container.read(appControllerProvider).requireValue.sessions,
        isEmpty,
      );
      await _tap(tester, 'Concluir demonstração');
      await tester.pumpAndSettle();
      expect(find.text('Início de teste'), findsOneWidget);
    },
  );

  testWidgets('deadline prepares a fictional result and cancels its timer', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    await _mount(tester, now: () => now);
    await _tap(tester, 'Iniciar simulação');
    now = now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('O tempo terminou'), findsOneWidget);
    await tester.pump(const Duration(seconds: 35));
    expect(find.text('O tempo terminou'), findsOneWidget);
  });

  testWidgets('real alert interrupts simulation and offers the real alert', (
    tester,
  ) async {
    final container = await _mount(tester);
    await _tap(tester, 'Iniciar simulação');
    (container.read(appControllerProvider.notifier) as _DemoApp).emitSnapshot(
      AppSnapshot(incidents: [_incident('PENDING')]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Existe um alerta real pendente'), findsOneWidget);
    await _tap(tester, 'Ver alerta real');
    await tester.pumpAndSettle();
    expect(find.text('Alerta real de teste'), findsOneWidget);
  });

  testWidgets('running protection blocks a new simulation', (tester) async {
    await _mount(tester, snapshot: const AppSnapshot(running: true));
    expect(find.text('Sua proteção está em andamento'), findsOneWidget);
    expect(find.text('Iniciar simulação'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'all simulation stages fit narrow screens and large text dark=$dark',
      (tester) async {
        await _mount(
          tester,
          dark: dark,
          size: const Size(320, 700),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Iniciar simulação');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Preciso de ajuda');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Experimentar outra resposta');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 31));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
