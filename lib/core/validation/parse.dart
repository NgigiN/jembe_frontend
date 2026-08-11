import 'package:farm_tracker/core/validation/sanitize.dart';

double? parseOptionalNonNegativeDecimal(String? value) {
  final sanitized = trimInput(value);
  if (sanitized.isEmpty) return null;
  final parsed = double.tryParse(sanitized);
  if (parsed == null || parsed < 0) return null;
  return parsed;
}

double? parsePositiveDecimal(String? value) {
  final sanitized = trimInput(value);
  if (sanitized.isEmpty) return null;
  final parsed = double.tryParse(sanitized);
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

double parseNonNegativeDecimal(String? value, {double fallback = 0}) {
  final sanitized = trimInput(value);
  if (sanitized.isEmpty) return fallback;
  final parsed = double.tryParse(sanitized);
  if (parsed == null || parsed < 0) return fallback;
  return parsed;
}

int? parsePositiveInt(String? value) {
  final sanitized = trimInput(value);
  if (sanitized.isEmpty) return null;
  final parsed = int.tryParse(sanitized);
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}