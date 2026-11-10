import 'package:flutter/services.dart';

String formatPhone(String? value) {
  if (value == null || value.isEmpty) return '';
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (!digits.startsWith('55')) return '+$digits';
  final local = digits.substring(2);
  var result = '+55';
  if (local.isNotEmpty) {
    result += ' (${local.substring(0, local.length.clamp(0, 2))}';
  }
  if (local.length >= 2) result += ')';
  if (local.length > 2) {
    final number = local.substring(2);
    final split = number.length > 8 ? 5 : 4;
    result += ' ${number.substring(0, number.length.clamp(0, split))}';
    if (number.length > split) result += '-${number.substring(split)}';
  }
  return result;
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 15) return oldValue;
    final end = newValue.selection.extentOffset.clamp(0, newValue.text.length);
    var before = newValue.text
        .substring(0, end)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    final previousDigits = oldValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits == previousDigits &&
        newValue.text.length < oldValue.text.length &&
        before > 0) {
      digits = digits.replaceRange(before - 1, before, '');
      before--;
    }
    if (digits.isEmpty) return TextEditingValue.empty;
    final formatted = formatPhone(digits);
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < before) {
      if (RegExp(r'[0-9]').hasMatch(formatted[offset])) seen++;
      offset++;
    }
    if (end == newValue.text.length) offset = formatted.length;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
