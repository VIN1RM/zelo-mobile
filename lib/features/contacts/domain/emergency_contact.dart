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

  static String? nameError(String value) =>
      value.trim().length < 2 || value.trim().length > 80
      ? 'O nome deve ter de 2 a 80 caracteres.'
      : null;

  static String? emailError(String? value) =>
      value != null &&
          (value.length > 254 ||
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value))
      ? 'Informe um e-mail válido.'
      : null;

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
    final invalidName = nameError(name);
    if (invalidName != null) {
      throw AppFailure(invalidName);
    }
    if (phone == null && email == null) {
      throw const AppFailure('Informe WhatsApp ou e-mail.');
    }
    final invalidEmail = emailError(email);
    if (invalidEmail != null) {
      throw AppFailure(invalidEmail);
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
