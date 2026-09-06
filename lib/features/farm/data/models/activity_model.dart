import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';

class ActivityModel extends Activity implements SyncableModel {
  const ActivityModel({
    required super.id,
    required super.sourceType,
    required super.sourceId,
    required super.type,
    required super.cost,
    required super.date,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
    super.animalId,
    super.details,
    super.notes,
  });
  factory ActivityModel.create({
    required String sourceType,
    required String sourceId,
    required String type, required double cost, required DateTime date, int? animalId,
    String? details,
    String? notes,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    return ActivityModel(
      id: '',
      clientUuid: clientUuid ?? uuid.v4(),
      // TODO(P4): unsynced-parent FK — animalId serializes to 0 / sourceId is
      // a clientUuid flag-on; translate + order parent-before-child before
      // push. P3 = synced-parent-only.
      sourceType: sourceType,
      sourceId: sourceId,
      animalId: animalId,
      type: type,
      details: details,
      cost: cost,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    final animalIdValue = json['AnimalID'] ?? json['animal_id'];
    final detailsValue = json['Details'] ?? json['details'];
    final costValue = json['Cost'] ?? json['cost'];
    final notesValue = json['Notes'] ?? json['notes'];
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];

    return ActivityModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      sourceType: (json['SourceType'] ?? json['source_type'] ?? 'plant')
          .toString(),
      sourceId: (json['SourceID'] ?? json['source_id'] ?? '').toString(),
      animalId: animalIdValue != null && animalIdValue != 0
          ? (animalIdValue is int
                ? animalIdValue
                : int.tryParse(animalIdValue.toString()))
          : null,
      type: (json['Type'] ?? json['type'] ?? '').toString(),
      details: detailsValue?.toString(),
      cost: costValue != null ? (costValue as num).toDouble() : 0.0,
      date: _parseDate(json['Date'] ?? json['date']),
      notes: notesValue?.toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''`
  /// (mirroring the server-unknown placeholder used by `.create()`).
  ///
  /// Also carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]) — the sync pipeline (`ActivitySyncer`) needs them to
  /// decide LWW / delete-wins outcomes on pull, since they otherwise only
  /// live on the drift row, not on a bare [ActivityModel].
  factory ActivityModel.fromDrift(ActivityRow row) {
    return ActivityModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      sourceType: row.sourceType,
      sourceId: row.sourceId,
      animalId: row.animalId,
      type: row.type,
      details: row.details,
      cost: row.cost,
      date: row.date,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this activity before (and independently of) the server-assigned
  /// [Activity.id]. Lives on the data model only — the domain `Activity`
  /// entity stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [Activity.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `ActivityLocalDataSource.markDeleted`). Always `false` on a model built
  /// from a server response (`fromJson`) or `create`.
  final bool deletedLocally;

  // TODO(P4): unsynced-parent FK — animalId serializes to 0 / sourceId is a
  // clientUuid flag-on; translate + order parent-before-child before push.
  // P3 = synced-parent-only.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_type': sourceType,
      'source_id': sourceId,
      'animal_id': animalId ?? 0,
      'type': type,
      'details': details,
      'cost': cost,
      'date': date.toIso8601String().split('T')[0],
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `Activities` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty).
  ActivitiesCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return ActivitiesCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      sourceType: Value(sourceType),
      sourceId: Value(sourceId),
      animalId: Value(animalId),
      type: Value(type),
      details: Value(details),
      cost: Value(cost),
      date: Value(date),
      notes: Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }

  // --- SyncableModel: the read-only sync fields BaseEntitySyncer reads off
  // this model, mapped onto ActivityModel's existing fields (the server id
  // lives on `id`, blank until synced; the local flags on
  // `pending`/`deletedLocally`).
  @override
  String get syncClientUuid => clientUuid;

  @override
  String get syncServerId => id;

  @override
  DateTime get syncUpdatedAt => updatedAt;

  @override
  bool get syncPending => pending;

  @override
  bool get syncDeletedLocally => deletedLocally;

  /// Returns this model with [clientUuid] substituted, every other field
  /// untouched — or `this` unchanged when it already carries [clientUuid]. Used
  /// by the pull reconciler to re-key a server row under the local row's client
  /// uuid before upserting. Mirrors `LandModel.withSyncClientUuid` verbatim:
  /// the copy carries no local sync flags (they default `false`), which is
  /// exactly how the pulled server row is always upserted.
  @override
  ActivityModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return ActivityModel(
      id: id,
      clientUuid: clientUuid,
      sourceType: sourceType,
      sourceId: sourceId,
      animalId: animalId,
      type: type,
      details: details,
      cost: cost,
      date: date,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  /// Returns a copy with [sourceId] overridden (a `null` arg keeps the
  /// current value), every other field untouched. Used by the P4 sync FK
  /// translator to substitute the polymorphic source parent's server id for
  /// its client_uuid before push. Reconstruct via the SAME constructor
  /// `withSyncClientUuid` uses.
  ///
  /// `animal_id` (int?) is NOT part of this — it can't carry a client_uuid,
  /// so it's left untouched here; see the `// TODO(P4)` note on `.create()`.
  ActivityModel withResolvedFks({String? sourceId}) {
    return ActivityModel(
      id: id,
      clientUuid: clientUuid,
      sourceType: sourceType,
      sourceId: sourceId ?? this.sourceId,
      animalId: animalId,
      type: type,
      details: details,
      cost: cost,
      date: date,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
