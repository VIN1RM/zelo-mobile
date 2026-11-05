import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/app/app.dart';

void main() {
  testWidgets('home clearly states that protection is not available yet', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ZeloApp()));

    expect(find.text('ZELO'), findsOneWidget);
    expect(find.text('O ZELO ainda está sendo preparado'), findsOneWidget);
    expect(
      find.textContaining('O aplicativo ainda não monitora trajetos'),
      findsOneWidget,
    );
  });

  testWidgets('main navigation opens the history placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ZeloApp()));

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
