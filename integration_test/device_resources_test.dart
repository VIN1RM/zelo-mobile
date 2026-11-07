import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zelo_mobile/core/platform/device_permissions.dart';
import 'package:zelo_mobile/features/device_resources/data/device_resources_gateway.dart';
import 'package:zelo_mobile/features/device_resources/domain/acceleration_reading.dart';
import 'package:zelo_mobile/features/monitoring/data/monitoring_gateway.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real native axes and local test notification while app is in background',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('ZELO — ensaio dos recursos nativos')),
          ),
        ),
      );
      final gateway = DeviceResourcesGateway();
      final readings = <AccelerationReading>[];
      final ready = Completer<void>();
      final subscription = gateway.watchAcceleration().listen(
        (value) {
          readings.add(value);
          if (readings.length >= 3 && !ready.isCompleted) ready.complete();
        },
        onError: (Object error) {
          if (!ready.isCompleted) ready.completeError(error);
        },
      );
      try {
        await ready.future.timeout(const Duration(seconds: 10));
        expect(
          readings.every((r) => r.x.isFinite && r.y.isFinite && r.z.isFinite),
          isTrue,
        );
        expect(
          await DeviceResourcesGateway.methods.invokeMethod<bool>(
            'accelerometerListening',
          ),
          isTrue,
        );
        expect(await DevicePermissions.requestNotifications(), isTrue);
        await gateway.notify(delaySeconds: 2);
        await MonitoringGateway.channel.invokeMethod<void>('testBackground', {
          'uid': 'integration-resources',
        });
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(
          await DeviceResourcesGateway.methods.invokeMethod<bool>(
            'accelerometerListening',
          ),
          isFalse,
        );
        expect(
          await DeviceResourcesGateway.methods.invokeMethod<bool>(
            'testNotificationVisible',
          ),
          isTrue,
        );
      } finally {
        await subscription.cancel();
        await DeviceResourcesGateway.methods.invokeMethod<void>(
          'clearTestNotification',
        );
      }
      expect(
        await DeviceResourcesGateway.methods.invokeMethod<bool>(
          'testNotificationVisible',
        ),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
