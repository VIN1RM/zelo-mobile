import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/platform/device_permissions.dart';
import '../../emergency/domain/location_snapshot.dart';
import '../domain/acceleration_reading.dart';

final deviceResourcesGatewayProvider = Provider(
  (ref) => DeviceResourcesGateway(),
);

class DeviceResourcesGateway {
  static const methods = MethodChannel('br.com.zelo/resources');
  static const events = EventChannel('br.com.zelo/resources/accelerometer');

  Stream<AccelerationReading> watchAcceleration() =>
      events.receiveBroadcastStream().map(AccelerationReading.fromNative);

  Future<Uint8List?> takePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (photo == null) return null;
      try {
        if (await photo.length() > 10 * 1024 * 1024) {
          throw const AppFailure(
            'A foto é muito grande. Tente capturar novamente.',
          );
        }
        return await photo.readAsBytes();
      } finally {
        // Camera captures are temporary demonstrations, never cloud attachments.
        final cache = await getTemporaryDirectory();
        final file = File(photo.path);
        final prefix = '${cache.absolute.path}${Platform.pathSeparator}';
        if (file.absolute.path.startsWith(prefix) && await file.exists()) {
          await file.delete();
        }
      }
    } on PlatformException {
      throw const AppFailure(
        'Não foi possível abrir a câmera. Confira as permissões nos ajustes do aparelho.',
      );
    }
  }

  Future<LocationSnapshot> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const AppFailure(
          'Ative a localização do aparelho e tente novamente.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw const AppFailure(
          'A localização não foi permitida. Autorize o acesso nas permissões do aplicativo.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationSnapshot(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        capturedAt: position.timestamp.toUtc(),
      );
    } on TimeoutException {
      throw const AppFailure(
        'A localização demorou para responder. Tente novamente perto de uma janela ou em local aberto.',
      );
    } on PlatformException {
      throw const AppFailure(
        'Não foi possível obter a localização. Confira o GPS e as permissões.',
      );
    }
  }

  Future<void> notify({int delaySeconds = 5}) async {
    if (!await DevicePermissions.requestNotifications()) {
      throw const AppFailure(
        'Permita as notificações do ZELO nas permissões do aplicativo.',
      );
    }
    try {
      await methods.invokeMethod<void>('testNotification', {
        'delaySeconds': delaySeconds,
      });
    } on PlatformException {
      throw const AppFailure(
        'Não foi possível agendar o teste. Confira se as notificações do ZELO e o canal de testes estão permitidos.',
      );
    }
  }
}
