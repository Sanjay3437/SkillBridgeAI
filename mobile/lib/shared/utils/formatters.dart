import 'package:intl/intl.dart';

String formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date.toLocal());

String formatShortDate(DateTime date) => DateFormat('MMM d').format(date.toLocal());

String formatPercent(double? value) {
  if (value == null) return '—';
  final rounded = value.roundToDouble();
  return '${rounded.toStringAsFixed(0)}%';
}

String initialsFor(String email) {
  final local = email.split('@').first.trim();
  if (local.isEmpty) return '?';
  final parts = local.split(RegExp(r'[._\- ]+')).where((part) => part.isNotEmpty).toList();
  if (parts.length >= 2) {
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
  return local[0].toUpperCase();
}
