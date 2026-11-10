import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelo_mobile/core/formatting/phone_format.dart';
import 'package:zelo_mobile/features/contacts/domain/emergency_contact.dart';

void main() {
  test('backspacing over a mask separator deletes the preceding digit', () {
    final result = PhoneInputFormatter().formatEditUpdate(
      const TextEditingValue(
        text: '+55 (11)',
        selection: TextSelection.collapsed(offset: 8),
      ),
      const TextEditingValue(
        text: '+55 (11',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );
    expect(result.text, '+55 (1');
  });

  test('Brazilian phone mask preserves the number used for sharing', () {
    final formatter = PhoneInputFormatter();
    const raw = '+5511999999999';
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: raw,
        selection: TextSelection.collapsed(offset: raw.length),
      ),
    );
    expect(result.text, '+55 (11) 99999-9999');
    expect(EmergencyContact.normalizePhone(result.text), raw);
    expect(formatPhone('+551133334444'), '+55 (11) 3333-4444');
  });
  test('international numbers and clearing do not lose digits', () {
    expect(formatPhone('+14155552671'), '+14155552671');
    expect(
      PhoneInputFormatter()
          .formatEditUpdate(
            const TextEditingValue(text: '+55'),
            TextEditingValue.empty,
          )
          .text,
      isEmpty,
    );
  });
}
