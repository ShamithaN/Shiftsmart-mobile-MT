import 'package:intl/intl.dart';

DateTime? parseServerDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;

  if (value is int || value is double) {
    return _parseEpoch(value);
  }

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final numeric = int.tryParse(raw);
  if (numeric != null) {
    return _parseEpoch(numeric);
  }

  final parsedIso = DateTime.tryParse(raw);
  if (parsedIso != null) return parsedIso;

  final cleaned = raw.replaceAll(RegExp(r'[\s]+'), ' ').trim();
  final patterns = [
    "yyyy-MM-dd HH:mm:ss",
    "yyyy-MM-dd HH:mm",
    "yyyy/MM/dd HH:mm:ss",
    "yyyy/MM/dd HH:mm",
    "dd/MM/yyyy HH:mm:ss",
    "dd/MM/yyyy HH:mm",
    "MM/dd/yyyy HH:mm:ss",
    "MM/dd/yyyy HH:mm",
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    "yyyy-MM-dd'T'HH:mm:ss.SSS",
    "yyyy-MM-dd'T'HH:mm:ss",
  ];

  for (final pattern in patterns) {
    try {
      final dt = DateFormat(pattern).parseLoose(cleaned, true);
      return dt;
    } catch (_) {
      continue;
    }
  }

  return null;
}

DateTime? _parseEpoch(dynamic value) {
  final epoch = value is double ? value.toInt() : value as int;
  if (epoch.abs() < 10000000000) {
    return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  }
  return DateTime.fromMillisecondsSinceEpoch(epoch);
}
