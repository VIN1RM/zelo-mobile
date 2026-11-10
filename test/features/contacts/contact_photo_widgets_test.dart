import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zelo_mobile/app/theme/app_theme.dart';
import 'package:zelo_mobile/features/contacts/data/contact_photo_picker.dart';
import 'package:zelo_mobile/features/contacts/domain/contact_photo.dart';
import 'package:zelo_mobile/features/contacts/domain/emergency_contact.dart';
import 'package:zelo_mobile/features/contacts/presentation/widgets/contact_avatar.dart';
import 'package:zelo_mobile/features/contacts/presentation/widgets/contact_photo_field.dart';

class _Picker extends ContactPhotoPicker {
  _Picker(this.image);
  final Uint8List image;
  final sources = <ImageSource>[];
  @override
  Future<Uint8List?> pick(ImageSource source) async {
    sources.add(source);
    return source == ImageSource.gallery ? image : null;
  }
}

Future<Uint8List> sampleImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 40, 20),
    ui.Paint()..color = const Color(0xFF176B80),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 20);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets(
    'detailed images are reduced to the enforced document byte budget',
    (tester) async {
      await tester.runAsync(() async {
        final random = Random(42);
        final pixels = Uint8List.fromList(
          List.generate(160 * 160 * 4, (_) => random.nextInt(256)),
        );
        final loaded = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          pixels,
          160,
          160,
          ui.PixelFormat.rgba8888,
          loaded.complete,
        );
        final image = await loaded.future;
        final original = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final normalized = await ContactPhotoPicker().normalize(
          original!.buffer.asUint8List(),
        );
        expect(normalized.length, lessThanOrEqualTo(64 * 1024));
        expect(ContactPhoto.validBytes(normalized), isTrue);
      });
    },
  );
  testWidgets('picked image becomes a compact square PNG', (tester) async {
    final bytes = await tester.runAsync(sampleImage);
    final normalized = await tester.runAsync(
      () => ContactPhotoPicker().normalize(bytes!),
    );
    expect(ContactPhoto.validBytes(normalized!), isTrue);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(normalized);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 160);
      expect(frame.image.height, 160);
      frame.image.dispose();
      codec.dispose();
    });
  });

  testWidgets(
    'gallery previews a photo, removal restores the initial, and camera cancel changes nothing',
    (tester) async {
      final bytes = await tester.runAsync(sampleImage);
      final picker = _Picker(bytes!);
      Uint8List? preview;
      var changes = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [contactPhotoPickerProvider.overrideWithValue(picker)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => ContactPhotoField(
                  contact: const EmergencyContact(
                    id: 'contact',
                    name: 'Ana',
                    priority: 1,
                  ),
                  preview: preview,
                  busy: false,
                  onBusyChanged: (_) {},
                  onChanged: (image) => setState(() {
                    preview = image;
                    changes++;
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('A'), findsOneWidget);
      await tester.tap(find.text('Galeria'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(changes, 1);
      await tester.tap(find.text('Remover foto'));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(preview, isNull);
      await tester.tap(find.text('Câmera'));
      await tester.pumpAndSettle();
      expect(changes, 2);
      expect(picker.sources, [ImageSource.gallery, ImageSource.camera]);
    },
  );

  testWidgets('private photo load failure retains a usable initial avatar', (
    tester,
  ) async {
    const path =
        'users/owner/contact_photos/contact/12345678-1234-1234-1234-123456789abc.png';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contactPhotoBytesProvider((
            contactId: 'contact',
            path: path,
          )).overrideWith((ref) async => throw StateError('offline')),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ContactAvatar(
              contact: const EmergencyContact(
                id: 'contact',
                name: 'Ana',
                priority: 1,
                photoPath: path,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
