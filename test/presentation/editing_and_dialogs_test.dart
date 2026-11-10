import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/app/theme/app_theme.dart';
import 'package:zelo_mobile/shared/widgets/app_view.dart';
import 'package:zelo_mobile/shared/widgets/unsaved_changes_guard.dart';

void main() {
  testWidgets(
    'save requires a change, restores its baseline, and disables after saving',
    (tester) async {
      final controller = TextEditingController(text: 'Original');
      final guard = GlobalKey<UnsavedChangesGuardState>();
      var writes = 0;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: UnsavedChangesGuard(
            key: guard,
            controllers: [controller],
            child: Scaffold(
              body: Column(
                children: [
                  TextField(controller: controller),
                  SaveChangesButton(
                    guard: guard,
                    label: 'Salvar',
                    onPressed: () async {
                      writes++;
                      await guard.currentState!.acceptChanges();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      FilledButton save() =>
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(save().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Alterado');
      await tester.pumpAndSettle();
      expect(save().onPressed, isNotNull);
      await tester.enterText(find.byType(TextField), 'Original');
      await tester.pumpAndSettle();
      expect(save().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Atualizado');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(save().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Original');
      await tester.pumpAndSettle();
      expect(save().onPressed, isNotNull);
    },
  );

  for (final enlarged in [false, true]) {
    testWidgets(
      'confirmation remains usable with ${enlarged ? 'large text' : 'standard text'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        bool? confirmed;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(enlarged ? 2 : 1)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    confirmed = await confirmAction(
                      context,
                      'Excluir contato?',
                      'Este contato sairá da sua rede de apoio.',
                    );
                  },
                  child: const Text('Abrir confirmação'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir confirmação'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Cancelar'));
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(confirmed, isFalse);
      },
    );
  }
}
