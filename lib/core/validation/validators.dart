import 'package:farm_tracker/core/validation/field_limits.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';

final RegExp _namePattern = RegExp(r"^[a-zA-Z0-9\s\-'.]+$");
final RegExp _locationPattern = RegExp(r"^[a-zA-Z0-9\s\-'.,]+$");

String? _requiredText(
  String? value, {
  required String fieldLabel,
  required int maxLength,
  required RegExp pattern,
  String? invalidCharsMessage,
}) {
  final sanitized = sanitizeText(value);
  if (sanitized.isEmpty) return '$fieldLabel is required';
  if (sanitized.length > maxLength) {
    return '$fieldLabel must be at most $maxLength characters';
  }
  if (!pattern.hasMatch(sanitized)) {
    return invalidCharsMessage ?? '$fieldLabel contains invalid characters';
  }
  return null;
}

String? _optionalText(
  String? value, {
  required String fieldLabel,
  required int maxLength,
  required RegExp pattern,
  String? invalidCharsMessage,
}) {
  final sanitized = sanitizeText(value);
  if (sanitized.isEmpty) return null;
  if (sanitized.length > maxLength) {
    return '$fieldLabel must be at most $maxLength characters';
  }
  if (!pattern.hasMatch(sanitized)) {
    return invalidCharsMessage ?? '$fieldLabel contains invalid characters';
  }
  return null;
}

String? requiredName(String? value, {String fieldLabel = 'Name'}) =>
    _requiredText(
      value,
      fieldLabel: fieldLabel,
      maxLength: FieldLimits.nameMax,
      pattern: _namePattern,
      invalidCharsMessage:
          "$fieldLabel may only contain letters, numbers, spaces, and - ' .",
    );

String? optionalName(String? value, {String fieldLabel = 'Name'}) =>
    _optionalText(
      value,
      fieldLabel: fieldLabel,
      maxLength: FieldLimits.nameMax,
      pattern: _namePattern,
      invalidCharsMessage:
          "$fieldLabel may only contain letters, numbers, spaces, and - ' .",
    );

String? requiredLocation(String? value, {String fieldLabel = 'Location'}) =>
    _requiredText(
      value,
      fieldLabel: fieldLabel,
      maxLength: FieldLimits.locationMax,
      pattern: _locationPattern,
      invalidCharsMessage:
          "$fieldLabel may only contain letters, numbers, spaces, and - ' . ,",
    );

String? optionalLocation(String? value, {String fieldLabel = 'Location'}) =>
    _optionalText(
      value,
      fieldLabel: fieldLabel,
      maxLength: FieldLimits.locationMax,
      pattern: _locationPattern,
      invalidCharsMessage:
          "$fieldLabel may only contain letters, numbers, spaces, and - ' . ,",
    );

String? optionalNotes(String? value, {String fieldLabel = 'Notes'}) =>
    _optionalText(
      value,
      fieldLabel: fieldLabel,
      maxLength: FieldLimits.notesMax,
      pattern: RegExp(r'^[\s\S]*$'),
    );

String? optionalSoilType(String? value) => _optionalText(
      value,
      fieldLabel: 'Soil type',
      maxLength: FieldLimits.soilTypeMax,
      pattern: _namePattern,
    );

String? optionalVariety(String? value) => _optionalText(
      value,
      fieldLabel: 'Variety',
      maxLength: FieldLimits.varietyMax,
      pattern: _namePattern,
    );

String? _parseDecimal(
  String? value, {
  required String fieldLabel,
  required bool required,
  required bool allowZero,
  required bool allowNegative,
}) {
  final sanitized = trimInput(value);
  if (sanitized.isEmpty) {
    return required ? '$fieldLabel is required' : null;
  }

  final parsed = double.tryParse(sanitized);
  if (parsed == null) return 'Enter a valid number for $fieldLabel';
  if (!allowNegative && parsed < 0) {
    return '$fieldLabel cannot be negative';
  }
  if (!allowZero && parsed <= 0) {
    return '$fieldLabel must be greater than zero';
  }
  if (parsed > FieldLimits.moneyMax) {
    return '$fieldLabel is too large';
  }

  final parts = sanitized.split('.');
  if (parts.length == 2 && parts[1].length > FieldLimits.decimalPlaces) {
    return '$fieldLabel allows at most ${FieldLimits.decimalPlaces} decimal places';
  }

  return null;
}

String? positiveDecimal(String? value, {String fieldLabel = 'Amount'}) =>
    _parseDecimal(
      value,
      fieldLabel: fieldLabel,
      required: true,
      allowZero: false,
      allowNegative: false,
    );

String? nonNegativeDecimal(String? value, {String fieldLabel = 'Amount'}) =>
    _parseDecimal(
      value,
      fieldLabel: fieldLabel,
      required: true,
      allowZero: true,
      allowNegative: false,
    );

String? optionalNonNegativeDecimal(
  String? value, {
  String fieldLabel = 'Amount',
}) =>
    _parseDecimal(
      value,
      fieldLabel: fieldLabel,
      required: false,
      allowZero: true,
      allowNegative: false,
    );

String? positiveInt(String? value, {String fieldLabel = 'Count'}) {
  final sanitized = trimInput(value);
  if (sanitized.isEmpty) return '$fieldLabel is required';

  final parsed = int.tryParse(sanitized);
  if (parsed == null) return 'Enter a valid whole number for $fieldLabel';
  if (parsed <= 0) return '$fieldLabel must be greater than zero';
  if (parsed > FieldLimits.intMax) return '$fieldLabel is too large';
  return null;
}

String? positiveIntMax(
  String? value, {
  required int max,
  String fieldLabel = 'Count',
}) {
  final baseError = positiveInt(value, fieldLabel: fieldLabel);
  if (baseError != null) return baseError;

  final parsed = int.parse(trimInput(value));
  if (parsed > max) {
    return '$fieldLabel cannot exceed $max';
  }
  return null;
}

String? requiredSelection<T>(T? value, {String fieldLabel = 'Selection'}) {
  if (value == null) return 'Please select a $fieldLabel';
  return null;
}

bool isDateNotInFuture(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final candidate = DateTime(date.year, date.month, date.day);
  return !candidate.isAfter(today);
}

String? validateDateNotInFuture(DateTime? date, {String fieldLabel = 'Date'}) {
  if (date == null) return '$fieldLabel is required';
  if (!isDateNotInFuture(date)) {
    return '$fieldLabel cannot be in the future';
  }
  return null;
}

String? validateEndDateAfterStart({
  required DateTime? start,
  required DateTime? end,
}) {
  if (end == null) return null;
  if (start == null) return null;
  if (end.isBefore(start)) {
    return 'End date must be on or after start date';
  }
  return null;
}