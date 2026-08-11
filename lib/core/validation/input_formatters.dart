import 'package:flutter/services.dart';
import 'package:farm_tracker/core/validation/field_limits.dart';

final RegExp _namePattern = RegExp(r"^[a-zA-Z0-9\s\-'.]+$");
final RegExp _locationPattern = RegExp(r"^[a-zA-Z0-9\s\-'.,]+$");
final RegExp _notesPattern = RegExp(r"^[\s\S]*$");

List<TextInputFormatter> nameFormatters({int maxLength = FieldLimits.nameMax}) =>
    [
      LengthLimitingTextInputFormatter(maxLength),
      FilteringTextInputFormatter.allow(_namePattern),
    ];

List<TextInputFormatter> shortLabelFormatters({
  int maxLength = FieldLimits.shortLabelMax,
}) =>
    nameFormatters(maxLength: maxLength);

List<TextInputFormatter> locationFormatters({
  int maxLength = FieldLimits.locationMax,
}) =>
    [
      LengthLimitingTextInputFormatter(maxLength),
      FilteringTextInputFormatter.allow(_locationPattern),
    ];

List<TextInputFormatter> notesFormatters({
  int maxLength = FieldLimits.notesMax,
}) =>
    [
      LengthLimitingTextInputFormatter(maxLength),
      FilteringTextInputFormatter.allow(_notesPattern),
    ];

List<TextInputFormatter> decimalFormatters({
  bool allowNegative = false,
  int maxLength = 12,
}) =>
    [
      LengthLimitingTextInputFormatter(maxLength),
      FilteringTextInputFormatter.allow(
        RegExp(allowNegative ? r'^-?\d*\.?\d{0,2}$' : r'^\d*\.?\d{0,2}$'),
      ),
    ];

List<TextInputFormatter> integerFormatters({
  int maxLength = 7,
}) =>
    [
      LengthLimitingTextInputFormatter(maxLength),
      FilteringTextInputFormatter.digitsOnly,
    ];