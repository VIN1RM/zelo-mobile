import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/app/theme/app_theme.dart';
import 'package:zelo_mobile/core/domain/app_failure.dart';
import 'package:zelo_mobile/features/device_resources/data/device_resources_gateway.dart';
import 'package:zelo_mobile/features/device_resources/domain/acceleration_reading.dart';
import 'package:zelo_mobile/features/device_resources/presentation/screens/device_resources_screen.dart';
import 'package:zelo_mobile/features/emergency/domain/location_snapshot.dart';

class _Gateway extends DeviceResourcesGateway {
  final readings = StreamController<AccelerationReading>.broadcast(sync: true);
  int notifications = 0;
  bool deny = false;
  int photos = 0;
  @override
  Stream<AccelerationReading> watchAcceleration() => readings.stream;
  @override
  Future<Uint8List?> takePhoto() async {
    photos++;
    if (deny) {
      throw const AppFailure('Câmera não permitida. Revise as permissões.');
    }
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j5WQAAAAASUVORK5CYII=',
    );
  }

  @override
  Future<LocationSnapshot> locate() async {
    if (deny) throw const AppFailure('A localização não foi permitida.');
    return LocationSnapshot(
      latitude: -16.319476,
      longitude: -48.938752,
      accuracy: 17,
      capturedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> notify({int delaySeconds = 5}) async {
    if (deny) throw const AppFailure('Notificações não permitidas.');
    notifications++;
  }
}

void main() {
  test('native axes require three finite values and preserve gravity', () {
    final reading = AccelerationReading.fromNative({
      'x': 0,
      'y': -0.25,
      'z': 9.81,
    });
    expect(reading.x, 0);
    expect(reading.y, -0.25);
    expect(reading.z, 9.81);
    for (final value in [
      null,
      {'x': 1, 'y': 2},
      {'x': double.nan, 'y': 0, 'z': 1},
      {'x': '1', 'y': 0, 'z': 1},
    ]) {
      expect(
        () => AccelerationReading.fromNative(value),
        throwsFormatException,
      );
    }
  });

  Future<void> open(WidgetTester tester, _Gateway gateway) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceResourcesGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const DeviceResourcesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'camera capture displays an image and GPS exposes named coordinates',
    (tester) async {
      final gateway = _Gateway();
      addTearDown(gateway.readings.close);
      await open(tester, gateway);
      await reveal(tester, 'Tirar foto');
      await tester.tap(find.text('Tirar foto'));
      await tester.pumpAndSettle();
      expect(gateway.photos, 1);
      expect(find.byType(Image), findsOneWidget);
      await reveal(tester, 'Obter coordenadas');
      await tester.tap(find.text('Obter coordenadas'));
      await tester.pumpAndSettle();
      expect(find.text('Latitude'), findsOneWidget);
      expect(find.text('Longitude'), findsOneWidget);
      expect(find.text('-16,319476°'), findsOneWidget);
      expect(find.text('-48,938752°'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'test notification is deliberate, scheduled once and permits another test after five seconds',
    (tester) async {
      final gateway = _Gateway();
      addTearDown(gateway.readings.close);
      await open(tester, gateway);
      await reveal(tester, 'Testar notificação em 5 segundos');
      await tester.tap(find.text('Testar notificação em 5 segundos'));
      await tester.pumpAndSettle();
      expect(gateway.notifications, 1);
      expect(
        find.textContaining('Teste agendado para daqui a 5 segundos'),
        findsOneWidget,
      );
      expect(find.text('Teste agendado…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Testar notificação em 5 segundos'), findsOneWidget);
      expect(
        find.textContaining('Abra a barra de notificações'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'sensor streams real readings, pauses when inactive and resumes without showing old data',
    (tester) async {
      final gateway = _Gateway();
      addTearDown(gateway.readings.close);
      await open(tester, gateway);
      await reveal(tester, '4. Acelerômetro ao vivo');
      gateway.readings.add(const AccelerationReading(x: 1.25, y: -2, z: 9.81));
      await tester.pumpAndSettle();
      expect(find.text('1,25 m/s²'), findsOneWidget);
      expect(find.text('-2,00 m/s²'), findsOneWidget);
      expect(find.text('9,81 m/s²'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.textContaining('Leitura pausada'), findsOneWidget);
      expect(gateway.readings.hasListener, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('1,25 m/s²'), findsNothing);
      gateway.readings.add(const AccelerationReading(x: 4, y: 5, z: 6));
      await tester.pumpAndSettle();
      expect(find.text('4,00 m/s²'), findsOneWidget);
      gateway.readings.addError(const FormatException('unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Acelerômetro indisponível'), findsOneWidget);
      expect(find.text('4,00 m/s²'), findsNothing);
    },
  );

  testWidgets(
    'denied permissions keep actions available with Portuguese feedback',
    (tester) async {
      final gateway = _Gateway()..deny = true;
      addTearDown(gateway.readings.close);
      await open(tester, gateway);
      await reveal(tester, 'Tirar foto');
      await tester.tap(find.text('Tirar foto'));
      await tester.pumpAndSettle();
      expect(
        find.text('Câmera não permitida. Revise as permissões.'),
        findsOneWidget,
      );
      await reveal(tester, 'Obter coordenadas');
      await tester.tap(find.text('Obter coordenadas'));
      await tester.pumpAndSettle();
      expect(find.text('A localização não foi permitida.'), findsOneWidget);
      await reveal(tester, 'Testar notificação em 5 segundos');
      await tester.tap(find.text('Testar notificação em 5 segundos'));
      await tester.pumpAndSettle();
      expect(find.text('Notificações não permitidas.'), findsOneWidget);
      expect(gateway.notifications, 0);
    },
  );
}
