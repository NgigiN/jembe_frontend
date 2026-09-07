import 'package:farm_tracker/core/utils/json_parsing.dart';
import 'package:farm_tracker/features/farm/domain/entities/trash_item.dart';

/// The 12 tombstone-fed entity keys `GET /api/v1/trash` groups its response
/// by (Phase 8 A2) — mirrors `TrashResponse` on the backend
/// (`internal/services/sync/trash_service.go`), itself generalized from
/// `deletionTables` (`internal/services/sync/deletions_service.go`).
/// `TrashPage` renders its sections in this order.
const trashEntities = [
  'land',
  'plant',
  'season',
  'activity',
  'input',
  'harvest',
  'animal_type',
  'herd',
  'animal',
  'infrastructure',
  'cost_category',
  'revenue',
];

class TrashItemModel extends TrashItem {
  const TrashItemModel({
    required super.entity,
    required super.id,
    required super.label,
    super.deletedAt,
  });

  factory TrashItemModel.fromRow(String entity, Map<String, dynamic> row) {
    // `id` is checked against the literal "ID" (not `dualKey`'s
    // capitalize-first-letter-only "Id") to match the actual PascalCase GORM
    // emits when a raw model (rather than a `*Response` DTO) is serialized
    // elsewhere in the app — see `LandModel.fromJson` for the same
    // convention.
    final id = (row['ID'] ?? row['id'] ?? '').toString();
    return TrashItemModel(
      entity: entity,
      id: id,
      label: _labelFor(row, id),
      deletedAt: _deletedAtOf(row),
    );
  }
}

/// Parses the grouped `GET /api/v1/trash` response body into a flat list —
/// one [TrashItemModel] per soft-deleted row, tagged with its entity key.
/// Deliberately generic (not 12 typed row models, matching Phase 8 B2's
/// "restore utility, not 12 CRUD views" scope): every row is handled as a
/// bare `Map<String, dynamic>`. An entity key missing from the response, or
/// present but null, contributes no items rather than throwing.
List<TrashItemModel> parseTrashResponse(Map<String, dynamic> json) {
  final items = <TrashItemModel>[];
  for (final entity in trashEntities) {
    final rows = json[entity] as List<dynamic>? ?? const [];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      items.add(TrashItemModel.fromRow(entity, row));
    }
  }
  return items;
}

DateTime? _deletedAtOf(Map<String, dynamic> row) {
  final value = dualKey(row, 'deleted_at');
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Best-effort display label, tried in priority order against whatever
/// fields the row actually carries:
///  1. `name`/`title` (land, plant, season, animal_type, herd, animal,
///     infrastructure, cost_category)
///  2. `type` + quantity/unit or amount + `date`, joined (activity, input,
///     revenue — e.g. "watering · 20.0 · 2026-09-01")
///  3. quantity+unit + `date` alone (harvest, which has neither name nor
///     type)
///  4. `date` alone
///  5. `#<id>` — nothing usable on the row.
String _labelFor(Map<String, dynamic> row, String id) {
  final name =
      _nonEmptyString(dualKey(row, 'name')) ??
      _nonEmptyString(dualKey(row, 'title'));
  if (name != null) return name;

  final descriptor = _nonEmptyString(dualKey(row, 'type'));
  final date = _nonEmptyString(dualKey(row, 'date'));
  final magnitude = _magnitudeOf(row);

  final parts = <String>[
    if (descriptor != null) descriptor,
    if (magnitude != null) magnitude,
    if (date != null) date,
  ];
  if (parts.isNotEmpty) return parts.join(' · ');

  return '#$id';
}

/// `"<quantity> <unit>"` when both are present, else the first present of
/// `amount`/`total`/`cost` (stringified) — a size/value hint for rows
/// (harvest, input, revenue, infrastructure, activity) that carry one.
String? _magnitudeOf(Map<String, dynamic> row) {
  final quantity = dualKey(row, 'quantity');
  final unit = _nonEmptyString(dualKey(row, 'unit'));
  if (quantity is num && unit != null) return '$quantity $unit';

  final amount = dualKey(row, 'amount') ?? dualKey(row, 'total') ?? dualKey(row, 'cost');
  if (amount is num) return amount.toString();

  return null;
}

String? _nonEmptyString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}
