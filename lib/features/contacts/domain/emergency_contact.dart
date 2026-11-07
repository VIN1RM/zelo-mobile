import '../../../core/domain/app_failure.dart';

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.priority,
    this.phone,
    this.email,
    this.revision = 0,
  });
  final String id;
  final String name;
  final int priority;
  final String? phone;
  final String? email;
  final int revision;

  static String? normalizePhone(String value) {
    if (value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (!value.trim().startsWith('+') ||
        digits.length < 8 ||
        digits.length > 15 ||
        digits.startsWith('0')) {
      throw const AppFailure(
        'Informe WhatsApp com +, código do país e DDD. Ex.: +5511999999999.',
      );
    }
    return '+$digits';
  }

  static void validate(String name, String? phone, String? email) {
    if (name.trim().length < 2 || name.trim().length > 80) {
      throw const AppFailure('O nome deve ter de 2 a 80 caracteres.');
    }
    if (phone == null && email == null) {
      throw const AppFailure('Informe WhatsApp ou e-mail.');
    }
    if (email != null &&
        (email.length > 254 ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      throw const AppFailure('Informe um e-mail válido.');
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'priority': priority,
    'phone': phone,
    'email': email,
  };
  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String,
        priority: json['priority'] as int,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        revision: json['revision'] as int? ?? 0,
      );
}
