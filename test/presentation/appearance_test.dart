import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/app/theme/theme_mode_provider.dart';
import 'package:zelo_mobile/shared/widgets/appearance_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'appearance survives a new app session and supports system mode',
    () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      await first.read(themeModeProvider.notifier).select(ThemeMode.dark);
      final second = ProviderContainer();
      addTearDown(second.dispose);
      await second.read(themeModeProvider.notifier).restore();
      expect(second.read(themeModeProvider), ThemeMode.dark);
      await second.read(themeModeProvider.notifier).select(ThemeMode.system);
      await first.read(themeModeProvider.notifier).restore();
      expect(first.read(themeModeProvider), ThemeMode.system);
    },
  );

  test('unknown saved appearance falls back to system', () async {
    FlutterSecureStorage.setMockInitialValues({
      ThemeModeController.storageKey: 'unknown',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeModeProvider.notifier).restore();
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  testWidgets('appearance menu changes the theme without leaving the screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: ref.watch(themeModeProvider),
              home: Scaffold(
                appBar: AppBar(actions: const [AppearanceSelector()]),
                body: const Text('Login'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<ThemeMode>, 'Modo escuro'),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Login'))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<ThemeMode>, 'Modo claro'),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Login'))).brightness,
      Brightness.light,
    );
  });
}
