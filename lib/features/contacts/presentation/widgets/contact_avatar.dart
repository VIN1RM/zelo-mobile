import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/application/app_controller.dart';
import '../../data/contact_photo_store.dart';
import '../../domain/emergency_contact.dart';

final contactPhotoCloudProvider = Provider<ContactPhotoCloud>(
  (ref) => FirestoreContactPhotoCloud(),
);
final contactPhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, ({String contactId, String path})>((ref, key) async {
      final repository = await ref.watch(repositoryProvider.future);
      return ContactPhotoStore(
        repository,
        cloud: ref.watch(contactPhotoCloudProvider),
      ).read(key.contactId, key.path);
    }, retry: (count, error) => null);

class ContactAvatar extends ConsumerWidget {
  const ContactAvatar({
    required this.contact,
    this.radius = 22,
    this.preview,
    super.key,
  });
  final EmergencyContact contact;
  final double radius;
  final Uint8List? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final path = contact.photoPath;
    final bytes =
        preview ??
        (path == null
            ? null
            : ref
                  .watch(
                    contactPhotoBytesProvider((
                      contactId: contact.id,
                      path: path,
                    )),
                  )
                  .asData
                  ?.value);
    final initial = contact.name.trim().isEmpty
        ? '?'
        : contact.name.trim().characters.first.toUpperCase();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(initial),
    );
    return Semantics(
      label: 'Foto de ${contact.name}',
      image: true,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: bytes == null
              ? fallback
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) => fallback,
                ),
        ),
      ),
    );
  }
}
