/// Sanitizes user input before submission.
String trimInput(String? value) => (value ?? '').trim();

String sanitizeText(String? value) {
  final trimmed = trimInput(value);
  if (trimmed.isEmpty) return trimmed;

  final buffer = StringBuffer();
  for (final codeUnit in trimmed.codeUnits) {
    // Reject control characters except common whitespace (space, tab).
    if (codeUnit < 32 && codeUnit != 9) continue;
    if (codeUnit == 127) continue;
    buffer.writeCharCode(codeUnit);
  }
  return buffer.toString();
}

String? sanitizeOptionalText(String? value) {
  final sanitized = sanitizeText(value);
  return sanitized.isEmpty ? null : sanitized;
}