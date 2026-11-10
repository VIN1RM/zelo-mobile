import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/app/app.dart';
import 'package:zelo_mobile/app/theme/app_theme.dart';
import 'package:zelo_mobile/core/application/app_controller.dart';
import 'package:zelo_mobile/core/platform/device_permissions.dart';
import 'package:zelo_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:zelo_mobile/features/contacts/domain/emergency_contact.dart';
import 'package:zelo_mobile/features/history/domain/history_filter.dart';
import 'package:zelo_mobile/features/onboarding/presentation/providers/readiness_provider.dart';
import 'package:zelo_mobile/features/onboarding/presentation/screens/preparation_screen.dart';
import 'package:zelo_mobile/features/settings/data/reminder_gateway.dart';
import 'package:zelo_mobile/features/settings/domain/device_diagnostics.dart';
import 'package:zelo_mobile/features/settings/domain/reminder_settings.dart';
import 'package:zelo_mobile/features/settings/presentation/screens/reminders_screen.dart';
import 'package:zelo_mobile/shared/widgets/unsaved_changes_guard.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_app_controller.dart';

class _ReadyController extends FakeAppController {
  @override
  Future<AppSnapshot> build() async => const AppSnapshot(
    prepared: true,
    contacts: [
      EmergencyContact(
        id: '1',
        name: 'Ana',
        priority: 0,
        phone: '+5511999999999',
      ),
    ],
  );
}

class _Reminders extends ReminderGateway {
  ReminderSettings? saved;
  @override
  Future<ReminderSettings> load(String uid) async => const ReminderSettings();
  @override
  Future<void> save(String uid, ReminderSettings settings) async {
    saved = settings;
  }

  @override
  Future<void> activate(String? uid) async {}
}

void main() {
  test(
    'history includes both boundary days and ignores accents and letter case',
    () {
      final period = DateTimeRange(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 9),
      );
      expect(
        matchesHistoryFilter(
          at: DateTime(2026, 11, 9, 23, 59),
          text: 'Ocorrência preservada',
          query: 'OCORRENCIA',
          period: period,
        ),
        isTrue,
      );
      expect(
        matchesHistoryFilter(
          at: DateTime(2026, 11, 1),
          text: 'Trajeto no bolso',
          query: 'bolso trajeto',
          period: period,
        ),
        isTrue,
      );
      expect(
        matchesHistoryFilter(
          at: DateTime(2026, 11, 10),
          text: 'Ocorrência',
          query: '',
          period: period,
        ),
        isFalse,
      );
      expect(
        matchesHistoryFilter(
          at: DateTime(2026, 11, 9),
          text: 'Trajeto',
          query: 'alerta',
        ),
        isFalse,
      );
    },
  );

  test('reminders default to off and reject invalid or repeated times', () {
    expect(const ReminderSettings().enabled, isFalse);
    expect(const ReminderSettings(minutes: [480, 480]).error, isNotNull);
    expect(const ReminderSettings(weekdays: []).error, isNotNull);
    expect(const ReminderSettings(minutes: [1440]).error, isNotNull);
    expect(const ReminderSettings(minutes: [480, 1080]).error, isNull);
  });

  testWidgets('unsaved form can stay or discard and return', (tester) async {
    final controller = TextEditingController(text: 'Original');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UnsavedChangesGuard(
                    controllers: [controller],
                    child: Scaffold(
                      appBar: AppBar(title: const Text('Editar')),
                      body: TextField(controller: controller),
                    ),
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alterado');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Alterado');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar e sair'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('system brightness selects the app dark theme', (tester) async {
    final auth = FakeAuthRepository(user: verifiedUser);
    addTearDown(auth.dispose);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          appControllerProvider.overrideWith(FakeAppController.new),
          reminderGatewayProvider.overrideWithValue(_Reminders()),
        ],
        child: const ZeloApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Proteção desativada'))).brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Proteção desativada'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('optional GPS and battery do not block a ready checklist', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_ReadyController.new),
          preparationReadinessProvider.overrideWith(
            (ref) async => const PreparationReadiness(
              device: DeviceDiagnostics(
                androidApi: 35,
                accelerometerAvailable: true,
                gyroscopeAvailable: true,
                notificationsEnabled: true,
                batteryOptimizationExempt: false,
              ),
              locationReady: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PreparationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 de 3 requisitos prontos'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Concluir preparação'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Concluir preparação'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'reminders require an explicit save and notification permission',
    (tester) async {
      final auth = FakeAuthRepository(user: verifiedUser);
      addTearDown(auth.dispose);
      final gateway = _Reminders();
      var allowed = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        DevicePermissions.channel,
        (call) async => allowed,
      );
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(DevicePermissions.channel, null),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          reminderGatewayProvider.overrideWithValue(gateway),
          authUserProvider.overrideWithValue(const AsyncData(verifiedUser)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const RemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(gateway.saved, isNull);
      await tester.scrollUntilVisible(
        find.text('Salvar lembretes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Salvar lembretes'));
      await tester.pumpAndSettle();
      expect(gateway.saved, isNull);
      expect(find.textContaining('Permita as notificações'), findsOneWidget);
      allowed = true;
      await tester.scrollUntilVisible(
        find.text('Salvar lembretes'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Salvar lembretes'));
      await tester.pumpAndSettle();
      expect(gateway.saved?.enabled, isTrue);
      expect(gateway.saved?.minutes, [480]);
    },
  );
}
