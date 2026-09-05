import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd_activity.dart';

/// Data model for the `herd_activity` offline outlier.
///
/// Unlike every other P3 entity, [HerdActivity] is CREATE-ONLY (no list, no
/// update, no delete) and has NO `updatedAt` of its own — the drift table's
/// `updated_at` column exists purely for the uniform sync-header schema (see
/// `HerdActivities` in `app_database.dart`) and is SYNTHESIZED from
/// [createdAt] wherever a value is needed ([toCompanion], [syncUpdatedAt]).
/// There is no last-writer-wins to do on pull — the bespoke
/// `HerdActivitySyncer` never pulls at all (nothing lists herd activities).
class HerdActivityModel extends HerdActivity implements SyncableModel {
  const HerdActivityModel({
    required super.id,
    required super.herdId,
    required super.activityType,
    required super.count,
    required super.date,
    required super.createdAt,
    super.notes,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
  });

  factory HerdActivityModel.create({
    required String herdId,
    required String activityType,
    required int count,
    required DateTime date,
    String? notes,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    return HerdActivityModel(
      id: '', // Server-unknown placeholder — set by `setServerId` on push.
      clientUuid: clientUuid ?? uuid.v4(),
      herdId: herdId,
      activityType: activityType,
      count: count,
      date: date,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  factory HerdActivityModel.fromJson(Map<String, dynamic> json) {
    return HerdActivityModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      herdId: (json['herd_id'] ?? json['HerdID'] ?? '').toString(),
      activityType: (json['activity_type'] ?? json['ActivityType'] ?? '').toString(),
      count: _parseInt(json['count'] ?? json['Count']),
      date: _parseDate(json['date'] ?? json['Date']),
      // The backend stores and returns this field as `reason`.
      notes: (json['reason'] ?? json['Reason'] ?? '').toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''` (mirroring
  /// the server-unknown placeholder used by `.create()`). The row also
  /// stores [herdId] — the syncer needs it to build the nested
  /// `/herds/:herdId/activities` push URL.
  ///
  /// Carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]); the row's `updated_at` column is deliberately NOT
  /// carried over — see class docs: it is synthesized fresh from
  /// [createdAt] wherever needed, never round-tripped.
  factory HerdActivityModel.fromDrift(HerdActivityRow row) {
    return HerdActivityModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      herdId: row.herdId,
      activityType: row.activityType,
      count: row.count,
      date: row.date,
      notes: row.notes,
      createdAt: row.createdAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/push pipeline to track
  /// this activity before (and independently of) the server-assigned
  /// [HerdActivity.id]. Lives on the data model only — the domain
  /// `HerdActivity` entity stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [HerdActivity.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column. Always `false` here —
  /// this entity is create-only and never deleted, but the flag is carried
  /// for schema uniformity with every other offline-mirrored table.
  final bool deletedLocally;

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  /// Wire body — preserved VERBATIM from the pre-offline model. OMITS
  /// [herdId] (it travels in the nested URL, not the body) and serializes
  /// [notes] under the backend's field name, `reason`.
  Map<String, dynamic> toJson() {
    return {
      'activity_type': activityType,
      'count': count,
      'date': date.toUtc().toIso8601String(),
      'reason': notes ?? '',
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `HerdActivities` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty). `updatedAt` is SYNTHETIC —
  /// set to [createdAt] (see class docs) since this entity has no real
  /// `updatedAt` of its own.
  HerdActivitiesCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return HerdActivitiesCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      herdId: Value(herdId),
      activityType: Value(activityType),
      count: Value(count),
      date: Value(date),
      notes: Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(createdAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }

  // --- SyncableModel: the read-only sync fields `HerdActivitySyncer` reads
  // off this model. [syncUpdatedAt] is SYNTHETIC — mapped to [createdAt]
  // (see class docs: no real `updatedAt` exists, and this entity never does
  // LWW on pull anyway — `HerdActivitySyncer.pull` never runs).
  @override
  String get syncClientUuid => clientUuid;

  @override
  String get syncServerId => id;

  @override
  DateTime get syncUpdatedAt => createdAt;

  @override
  bool get syncPending => pending;

  @override
  bool get syncDeletedLocally => deletedLocally;

  /// Returns this model with [clientUuid] substituted, every other field
  /// untouched — or `this` unchanged when it already carries [clientUuid].
  /// Part of the [SyncableModel] contract; not currently exercised by
  /// `HerdActivitySyncer` (its `pull` never runs — see class docs), kept for
  /// contract symmetry with every other entity's model. Mirrors
  /// `LandModel.withSyncClientUuid` verbatim: the copy carries no local sync
  /// flags (they default `false`).
  @override
  HerdActivityModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return HerdActivityModel(
      id: id,
      clientUuid: clientUuid,
      herdId: herdId,
      activityType: activityType,
      count: count,
      date: date,
      notes: notes,
      createdAt: createdAt,
    );
  }
}
