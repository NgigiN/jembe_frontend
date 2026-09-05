import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';

class SeasonModel extends Season implements SyncableModel {
  const SeasonModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.plantId,
    required super.landId,
    required super.startDate,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
    super.endDate,
  });

  factory SeasonModel.create({
    required String userId,
    required String name,
    required String plantId,
    required String landId,
    required DateTime startDate,
    DateTime? endDate,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    return SeasonModel(
      id: '', // Will be set by the server
      clientUuid: clientUuid ?? uuid.v4(),
      userId: userId,
      name: name,
      // TODO(P4): unsynced-parent FK reconciliation — plantId/landId are
      // client-side ids; an unsynced parent serializes '' and the server
      // create will reject/mislink. P3 supports create under an
      // ALREADY-SYNCED parent only.
      plantId: plantId,
      landId: landId,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory SeasonModel.fromJson(Map<String, dynamic> json) {
    final endDateValue = json['EndDate'] ?? json['end_date'];
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];
    return SeasonModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      plantId: (json['PlantID'] ?? json['plant_id'] ?? '').toString(),
      landId: (json['LandID'] ?? json['land_id'] ?? '').toString(),
      startDate: _parseDate(json['StartDate'] ?? json['start_date']),
      endDate: endDateValue != null && endDateValue.toString().isNotEmpty
          ? _parseDate(endDateValue)
          : null,
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''`
  /// (mirroring the server-unknown placeholder used by `.create()`).
  ///
  /// Also carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]) — the sync pipeline (`SeasonSyncer`) needs them to
  /// decide LWW / delete-wins outcomes on pull, since they otherwise only
  /// live on the drift row, not on a bare [SeasonModel].
  factory SeasonModel.fromDrift(SeasonRow row) {
    return SeasonModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      userId: row.userId,
      name: row.name,
      plantId: row.plantId,
      landId: row.landId,
      startDate: row.startDate,
      endDate: row.endDate,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this season before (and independently of) the server-assigned
  /// [Season.id]. Lives on the data model only — the domain `Season` entity
  /// stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [Season.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `SeasonLocalDataSource.markDeleted`). Always `false` on a model built
  /// from a server response (`fromJson`) or `create`.
  final bool deletedLocally;

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_uuid': clientUuid,
      'user_id': userId,
      'name': name,
      // TODO(P4): unsynced-parent FK reconciliation — plantId/landId are
      // client-side ids; an unsynced parent serializes '' and the server
      // create will reject/mislink. P3 supports create under an
      // ALREADY-SYNCED parent only.
      'plant_id': plantId,
      'land_id': landId,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `Seasons` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty).
  SeasonsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return SeasonsCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      name: Value(name),
      plantId: Value(plantId),
      landId: Value(landId),
      startDate: Value(startDate),
      endDate: Value(endDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }

  // --- SyncableModel: the read-only sync fields BaseEntitySyncer reads off
  // this model, mapped onto SeasonModel's existing fields (the server id
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
  SeasonModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return SeasonModel(
      id: id,
      clientUuid: clientUuid,
      userId: userId,
      name: name,
      plantId: plantId,
      landId: landId,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
