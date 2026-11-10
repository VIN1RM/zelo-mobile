import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/domain/app_failure.dart';
import '../domain/contact_photo.dart';

final contactPhotoPickerProvider = Provider<ContactPhotoPicker>(
  (ref) => ContactPhotoPicker(),
);

class ContactPhotoPicker {
  Future<Uint8List?> pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return null;
    try {
      if (await image.length() > 8 * 1024 * 1024) {
        throw const AppFailure('Escolha uma imagem de até 8 MB.');
      }
      return normalize(await image.readAsBytes());
    } finally {
      final temporary = await getTemporaryDirectory();
      final file = File(image.path);
      if (file.absolute.path.startsWith(
        '${temporary.absolute.path}${Platform.pathSeparator}',
      )) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<Uint8List> normalize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final side = image.width < image.height ? image.width : image.height;
        for (final size in [160, 128, 112]) {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          canvas.drawImageRect(
            image,
            ui.Rect.fromLTWH(
              (image.width - side) / 2,
              (image.height - side) / 2,
              side.toDouble(),
              side.toDouble(),
            ),
            ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
            ui.Paint(),
          );
          final picture = recorder.endRecording();
          try {
            final resized = await picture.toImage(size, size);
            try {
              final data = await resized.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (data != null) {
                final result = data.buffer.asUint8List();
                if (ContactPhoto.validBytes(result)) return result;
              }
            } finally {
              resized.dispose();
            }
          } finally {
            picture.dispose();
          }
        }
        throw const AppFailure(
          'Não foi possível preparar uma miniatura de até 64 KB.',
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
