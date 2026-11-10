import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../data/contact_photo_picker.dart';
import '../../domain/emergency_contact.dart';
import 'contact_avatar.dart';

class ContactPhotoField extends ConsumerStatefulWidget {
  const ContactPhotoField({
    required this.contact,
    required this.preview,
    required this.busy,
    required this.onChanged,
    required this.onBusyChanged,
    super.key,
  });
  final EmergencyContact contact;
  final Uint8List? preview;
  final bool busy;
  final ValueChanged<Uint8List?> onChanged;
  final ValueChanged<bool> onBusyChanged;
  @override
  ConsumerState<ContactPhotoField> createState() => _ContactPhotoFieldState();
}

class _ContactPhotoFieldState extends ConsumerState<ContactPhotoField> {
  bool _picking = false;
  Future<void> pick(ImageSource source) async {
    if (_picking || widget.busy) return;
    setState(() => _picking = true);
    widget.onBusyChanged(true);
    try {
      await uiAction(context, () async {
        final bytes = await ref.read(contactPhotoPickerProvider).pick(source);
        if (bytes != null && mounted) widget.onChanged(bytes);
      });
    } finally {
      if (mounted) {
        setState(() => _picking = false);
        widget.onBusyChanged(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      children: [
        ContactAvatar(
          contact: widget.contact,
          preview: widget.preview,
          radius: 44,
        ),
        const SizedBox(height: 12),
        Text('Foto do contato', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Opcional. A foto será sincronizada com sua conta.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ResponsiveActions(
          minimumWidth: 112,
          children: [
            OutlinedButton.icon(
              onPressed: widget.busy || _picking
                  ? null
                  : () => pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Câmera'),
            ),
            OutlinedButton.icon(
              onPressed: widget.busy || _picking
                  ? null
                  : () => pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Galeria'),
            ),
          ],
        ),
        if (_picking)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(semanticsLabel: 'Preparando foto'),
          ),
        if (widget.preview != null || widget.contact.photoPath != null)
          TextButton.icon(
            onPressed: widget.busy || _picking
                ? null
                : () => widget.onChanged(null),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Remover foto'),
          ),
      ],
    ),
  );
}
