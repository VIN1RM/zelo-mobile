import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/app/theme/app_theme.dart';
import 'package:zelo_mobile/features/settings/presentation/screens/licenses_screen.dart';
import 'package:zelo_mobile/features/settings/presentation/widgets/about_dialog.dart';

Future<Map<String, List<List<LicenseParagraph>>>> sampleLicenses() async => {
  'flutter': [
    LicenseEntryWithLineBreaks([
      'flutter',
    ], 'Original Flutter license.').paragraphs.toList(),
  ],
  'Karla': [
    LicenseEntryWithLineBreaks([
      'Karla',
    ], 'Original font license.\n\nCopyright notice.').paragraphs.toList(),
  ],
};

void main() {
  testWidgets(
    'licenses can be searched, read and returned to without losing the search',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const LicensesScreen(loader: sampleLicenses),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'karla');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Karla'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Karla'));
      await tester.pumpAndSettle();
      expect(find.text('Original font license.'), findsOneWidget);
      expect(find.text('Copyright notice.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Karla'), findsOneWidget);
      expect(find.text('flutter'), findsNothing);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Nenhum componente encontrado'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nenhum componente encontrado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed license loading can be retried', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LicensesScreen(
          loader: () async {
            if (++attempts == 1) throw StateError('unavailable');
            return sampleLicenses();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Karla'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('about dialog returns an explicit choice to open licenses', (
    tester,
  ) async {
    bool? choice;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  choice = await showZeloAboutDialog(context),
              child: const Text('Sobre'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sobre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver licenças e créditos'));
    await tester.pumpAndSettle();
    expect(choice, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
