import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../settings/domain/device_diagnostics.dart';
import '../../../settings/presentation/providers/diagnostics_provider.dart';

class PreparationReadiness {
  const PreparationReadiness({
    required this.device,
    required this.locationReady,
  });
  final DeviceDiagnostics device;
  final bool? locationReady;
  bool get sensorsReady =>
      device.accelerometerAvailable && device.gyroscopeAvailable;
}

final preparationReadinessProvider =
    FutureProvider.autoDispose<PreparationReadiness>((ref) async {
      final device = await ref.watch(deviceDiagnosticsProvider.future);
      bool? location;
      try {
        final permission = await Geolocator.checkPermission();
        location =
            (permission == LocationPermission.always ||
                permission == LocationPermission.whileInUse) &&
            await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        location = null;
      }
      return PreparationReadiness(device: device, locationReady: location);
    }, retry: (count, error) => null);
