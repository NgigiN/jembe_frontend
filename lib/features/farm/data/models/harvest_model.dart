import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';

class HarvestModel extends Harvest implements SyncableModel {

  const HarvestModel({
    required super.id,
    required super.seasonId,
    required super.quantity,
    required super.unit,
    required super.date,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
    super.notes,
    super.revenueId,
  });
  factory HarvestModel.create({
    required String seasonId,
    required double quantity,
    required String unit,
    required DateTime date,
    String? notes,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    return HarvestModel(
      id: '',
      clientUuid: clientUuid ?? uuid.v4(),
      // TODO(P4): unsynced/clientUuid-parent FK reconciliation — translate
      // parent clientUuid→server id + parent-before-child ordering before
      // push. P3 supports create under an ALREADY-SYNCED parent only.
      seasonId: seasonId,
      quantity: quantity,
      unit: unit,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory HarvestModel.fromJson(Map<String, dynamic> json) {
    final revenueIdValue = json['RevenueID'] ?? json['revenue_id'];
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];

    return HarvestModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      seasonId: (json['SeasonID'] ?? json['season_id'] ?? '').toString(),
      quantity: ((json['Quantity'] ?? json['quantity'] ?? 0) as num).toDouble(),
      unit: (json['Unit'] ?? json['unit'] ?? '').toString(),
      date: _parseDate(json['Date'] ?? json['date']),
      notes: (json['Notes'] ?? json['notes'])?.toString(),
      revenueId: revenueIdValue != null && revenueIdValue != 0
          ? revenueIdValue.toString()
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
  /// [deletedLocally]) — the sync pipeline (`HarvestSyncer`) needs them to
  /// decide LWW / delete-wins outcomes on pull, since they otherwise only
  /// live on the drift row, not on a bare [HarvestModel].
  factory HarvestModel.fromDrift(HarvestRow row) {
    return HarvestModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      seasonId: row.seasonId,
      quantity: row.quantity,
      unit: row.unit,
      date: row.date,
      notes: row.notes,
      revenueId: row.revenueId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this harvest before (and independently of) the server-assigned
  /// [Harvest.id]. Lives on the data model only — the domain `Harvest`
  /// entity stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [Harvest.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `HarvestLocalDataSource.markDeleted`). Always `false` on a model built
  /// from a server response (`fromJson`) or `create`.
  final bool deletedLocally;

  Map<String, dynamic> toJson() {
    return {
      'season_id': int.tryParse(seasonId) ?? seasonId,
      'quantity': quantity,
      'unit': unit,
      'date': date.toUtc().toIso8601String(),
      'notes': notes ?? '',
      if (revenueId != null) 'revenue_id': int.tryParse(revenueId!) ?? revenueId,
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `Harvests` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty).
  HarvestsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return HarvestsCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      seasonId: Value(seasonId),
      quantity: Value(quantity),
      unit: Value(unit),
      date: Value(date),
      notes: Value(notes),
      revenueId: Value(revenueId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }

  // --- SyncableModel: the read-only sync fields BaseEntitySyncer reads off
  // this model, mapped onto HarvestModel's existing fields (the server id
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
  HarvestModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return HarvestModel(
      id: id,
      clientUuid: clientUuid,
      seasonId: seasonId,
      quantity: quantity,
      unit: unit,
      date: date,
      notes: notes,
      revenueId: revenueId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Returns a copy with the given FK fields overridden (each `null` arg keeps
  /// the current value), every other field untouched. Used by the P4 sync FK
  /// translator to substitute a parent's server id for its client_uuid before
  /// push. Reconstruct via the SAME constructor `withSyncClientUuid` uses.
  HarvestModel withResolvedFks({String? seasonId, String? revenueId}) {
    return HarvestModel(
      id: id,
      clientUuid: clientUuid,
      seasonId: seasonId ?? this.seasonId,
      quantity: quantity,
      unit: unit,
      date: date,
      notes: notes,
      revenueId: revenueId ?? this.revenueId,
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
}
