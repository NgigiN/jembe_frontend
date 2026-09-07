/// Shared, tolerant JSON-parsing helpers for the hand-written farm feature
/// models.
///
/// The backend has, over time, returned both PascalCase field names (GORM's
/// default JSON tags, e.g. `CreatedAt`) and snake_case field names (the
/// documented API convention, e.g. `created_at`) for the same resource.
/// Every model tolerates both by checking whichever casing is present in the
/// response.
///
/// These helpers were previously copy-pasted as private static methods on
/// 13 separate model classes (12 under `features/farm/data/models` plus
/// `QuestionModel`). [parseDate] intentionally uses the more tolerant
/// [DateTime.tryParse] (falling back to [DateTime.now] instead of throwing
/// on a malformed string) — this was already the effective behavior for
/// null/missing values in every copy, and no existing test pins the
/// stricter throw-on-malformed-string behavior of the old `DateTime.parse`
/// call, so consolidating onto the tolerant form is behavior-preserving in
/// practice while being strictly safer.
library;

/// Parses a date value that may be `null`, a non-string, or an ISO-8601
/// string. Falls back to [DateTime.now] for anything that isn't a
/// successfully parsed string, rather than throwing.
DateTime parseDate(dynamic dateValue) {
  if (dateValue is String) {
    final parsed = DateTime.tryParse(dateValue);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

/// Parses an int value that may already be an [int]/[num], a numeric
/// [String], or `null`. Falls back to `0`.
int parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

/// Parses a double value that may already be a [double]/[num], a numeric
/// [String], or `null`. Falls back to `0`.
double parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

/// Looks up a field that may arrive under either casing convention: the
/// PascalCase form of [snakeCaseKey] (checked first) or [snakeCaseKey]
/// itself (the fallback) — i.e. `json['CreatedAt'] ?? json['created_at']`
/// for `dualKey(json, 'created_at')`. This mirrors the exact lookup order
/// already used at every `createdAt`/`updatedAt` call site.
dynamic dualKey(Map<String, dynamic> json, String snakeCaseKey) {
  return json[_toPascalCase(snakeCaseKey)] ?? json[snakeCaseKey];
}

String _toPascalCase(String snakeCase) {
  return snakeCase
      .split('_')
      .map(
        (part) =>
            part.isEmpty ? part : part[0].toUpperCase() + part.substring(1),
      )
      .join();
}
