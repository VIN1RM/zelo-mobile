import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/features/settings/data/android_diagnostics_gateway.dart';
import 'package:zelo_mobile/features/settings/presentation/screens/device_diagnostics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const gateway = AndroidDiagnosticsGateway();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Map<String, Object> response({bool available = true}) => {
    'androidApi': 35,
    'accelerometerAvailable': available,
    'gyroscopeAvailable': available,
    'notificationsEnabled': available,
    'batteryOptimizationExempt': false,
  };

  tearDown(() {
    messenger.setMockMethodCallHandler(AndroidDiagnosticsGateway.channel, null);
  });

  test('absent resources remain absent across the native boundary', () async {
    messenger.setMockMethodCallHandler(
      AndroidDiagnosticsGateway.channel,
      (call) async => response(available: false),
    );
    final result = await gateway.read();
    expect(result.androidApi, 35);
    expect(result.accelerometerAvailable, isFalse);
    expect(result.gyroscopeAvailable, isFalse);
    expect(result.notificationsEnabled, isFalse);
    expect(result.batteryOptimizationExempt, isFalse);
  });

  test(
    'incomplete native response is rejected instead of inventing status',
    () async {
      messenger.setMockMethodCallHandler(
        AndroidDiagnosticsGateway.channel,
        (call) async => {'androidApi': 35},
      );
      await expectLater(gateway.read(), throwsFormatException);
    },
  );

  testWidgets('failure can be retried and does not imply active protection', (
    tester,
  ) async {
    var reads = 0;
    messenger.setMockMethodCallHandler(AndroidDiagnosticsGateway.channel, (
      call,
    ) async {
      if (++reads == 1) throw PlatformException(code: 'UNAVAILABLE');
      return response(available: false);
    });
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DeviceDiagnosticsScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível consultar'), findsOneWidget);
    expect(find.text('Acelerômetro'), findsNothing);

    await tester.tap(find.text('Atualizar diagnóstico'));
    await tester.pumpAndSettle();
    expect(find.text('Indisponível'), findsNWidgets(2));
    expect(find.text('Não permitidas pelo sistema'), findsOneWidget);
    expect(find.text('Proteção ativa'), findsNothing);
    expect(reads, 2);
  });

  testWidgets('returning from Android settings refreshes permissions', (
    tester,
  ) async {
    var allowed = false;
    messenger.setMockMethodCallHandler(
      AndroidDiagnosticsGateway.channel,
      (call) async => response(available: allowed),
    );
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DeviceDiagnosticsScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não permitidas pelo sistema'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    allowed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Permitidas pelo sistema'), findsOneWidget);
  });
}
