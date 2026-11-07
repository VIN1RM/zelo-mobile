import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/android_diagnostics_gateway.dart';
import '../../domain/device_diagnostics.dart';

final diagnosticsGatewayProvider = Provider<AndroidDiagnosticsGateway>(
  (ref) => const AndroidDiagnosticsGateway(),
);

final deviceDiagnosticsProvider = FutureProvider.autoDispose<DeviceDiagnostics>(
  (ref) => ref.watch(diagnosticsGatewayProvider).read(),
  retry: (retryCount, error) => null,
);
