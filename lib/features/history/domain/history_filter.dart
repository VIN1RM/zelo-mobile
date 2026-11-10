import 'package:flutter/material.dart';

String searchableText(String value) {
  const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const plain = 'aaaaaeeeeiiiiooooouuuuc';
  var text = value.toLowerCase();
  for (var index = 0; index < accents.length; index++) {
    text = text.replaceAll(accents[index], plain[index]);
  }
  return text;
}

bool matchesHistoryFilter({
  required DateTime at,
  required String text,
  required String query,
  DateTimeRange? period,
}) {
  final local = at.toLocal();
  if (period != null) {
    final day = DateTime(local.year, local.month, local.day);
    if (day.isBefore(DateUtils.dateOnly(period.start)) ||
        day.isAfter(DateUtils.dateOnly(period.end))) {
      return false;
    }
  }
  final normalized = searchableText(text);
  return searchableText(
    query,
  ).trim().split(RegExp(r'\s+')).every(normalized.contains);
}
