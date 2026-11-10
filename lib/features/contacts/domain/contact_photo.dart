import 'dart:typed_data';

abstract final class ContactPhoto {
  static const maximumBytes = 64 * 1024;
  static String path(String uid, String contactId, String photoId) =>
      'users/$uid/contact_photos/$contactId/versions/$photoId';
  static String canonicalPath(String path) {
    final parts = path.split('/');
    if (parts.length == 6 &&
        parts[0] == 'users' &&
        parts[2] == 'contact_photos' &&
        parts[4] == 'versions') {
      return path;
    }
    if (parts.length == 5 &&
        parts[0] == 'users' &&
        parts[2] == 'contact_photos' &&
        parts[4].endsWith('.png')) {
      return 'users/${parts[1]}/contact_photos/${parts[3]}/versions/${parts[4].substring(0, parts[4].length - 4)}';
    }
    throw const FormatException('Referência de miniatura inválida.');
  }

  static bool validPath(String uid, String contactId, String path) {
    if (contactId.contains('/')) return false;
    try {
      final parts = canonicalPath(path).split('/');
      return parts[1] == uid &&
          parts[3] == contactId &&
          RegExp(r'^[a-f0-9-]{36}$').hasMatch(parts[5]);
    } on FormatException {
      return false;
    }
  }

  static bool validBytes(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes.length <= maximumBytes &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10;
}
