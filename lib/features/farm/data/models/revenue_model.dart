import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/core/utils/json_parsing.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';

class RevenueModel extends Revenue implements SyncableModel {
  const RevenueModel({
    required super.id,
    required super.userId,
    required super.source,
    required super.sourceId,
    required super.type,
    required super.quantity,
    required super.unitPrice,
    required super.total,
    required super.date,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
    super.notes,
  });

  factory RevenueModel.create({
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required DateTime date,
    double? total,
    String? notes,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    final calculatedTotal = total ?? (quantity * unitPrice);
    return RevenueModel(
      id: '',
      clientUuid: clientUuid ?? uuid.v4(),
      userId: '',
      source: source,
      // sourceId may hold an unsynced parent's client_uuid here; the
      // syncer's `translateRevenueFks` (fk_translators.dart) resolves it to
      // the parent's server id at push time via
      // `BaseEntitySyncer.resolveFks`.
      sourceId: sourceId,
      type: type,
      quantity: quantity,
      unitPrice: unitPrice,
      total: calculatedTotal,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory RevenueModel.fromJson(Map<String, dynamic> json) {
    final notesValue = json['notes'] ?? json['Notes'];
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];

    return RevenueModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      userId: (json['user_id'] ?? json['UserID'] ?? '').toString(),
      source: (json['source'] ?? json['Source'] ?? '').toString(),
      sourceId: (json['source_id'] ?? json['SourceID'] ?? '').toString(),
      type: (json['type'] ?? json['Type'] ?? '').toString(),
      quantity: parseDouble(json['quantity'] ?? json['Quantity']),
      unitPrice: parseDouble(json['unit_price'] ?? json['UnitPrice']),
      total: parseDouble(json['total'] ?? json['Total']),
      date: parseDate(json['date'] ?? json['Date']),
      notes: notesValue?.toString(),
      createdAt: parseDate(dualKey(json, 'created_at')),
      updatedAt: parseDate(dualKey(json, 'updated_at')),
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''`
  /// (mirroring the server-unknown placeholder used by `.create()`).
  ///
  /// Also carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]) — the sync pipeline (`RevenueSyncer`) needs them to
  /// decide LWW / delete-wins outcomes on pull, since they otherwise only
  /// live on the drift row, not on a bare [RevenueModel].
  factory RevenueModel.fromDrift(RevenueRow row) {
    return RevenueModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      userId: row.userId,
      source: row.source,
      sourceId: row.sourceId,
      type: row.type,
      quantity: row.quantity,
      unitPrice: row.unitPrice,
      total: row.total,
      date: row.date,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this revenue before (and independently of) the server-assigned
  /// [Revenue.id]. Lives on the data model only — the domain `Revenue`
  /// entity stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [Revenue.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `RevenueLocalDataSource.markDeleted`). Always `false` on a model built
  /// from a server response (`fromJson`) or `create`.
  final bool deletedLocally;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'source': source,
      // sourceId may hold an unsynced parent's client_uuid here; the
      // syncer's `translateRevenueFks` (fk_translators.dart) resolves it to
      // the parent's server id at push time via
      // `BaseEntitySyncer.resolveFks`.
      'source_id': int.tryParse(sourceId) ?? sourceId,
      'type': type,
      'quantity': quantity,
      'unit_price': unitPrice,
      'date': date.toUtc().toIso8601String(),
    };

    if (total > 0) {
      json['total'] = total;
    }

    if (notes != null && notes!.isNotEmpty) {
      json['notes'] = notes;
    }

    return json;
  }

  /// Converts this model into a drift insert/update companion for the
  /// `Revenues` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty).
  RevenuesCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return RevenuesCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      source: Value(source),
      sourceId: Value(sourceId),
      type: Value(type),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      total: Value(total),
      date: Value(date),
      notes: Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }

  // --- SyncableModel: the read-only sync fields BaseEntitySyncer reads off
  // this model, mapped onto RevenueModel's existing fields (the server id
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
  RevenueModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return RevenueModel(
      id: id,
      clientUuid: clientUuid,
      userId: userId,
      source: source,
      sourceId: sourceId,
      type: type,
      quantity: quantity,
      unitPrice: unitPrice,
      total: total,
      date: date,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Returns a copy with [sourceId] overridden (a `null` arg keeps the
  /// current value), every other field untouched. Used by the P4 sync FK
  /// translator to substitute the polymorphic source parent's server id for
  /// its client_uuid before push. Reconstruct via the SAME constructor
  /// `withSyncClientUuid` uses.
  RevenueModel withResolvedFks({String? sourceId}) {
    return RevenueModel(
      id: id,
      clientUuid: clientUuid,
      userId: userId,
      source: source,
      sourceId: sourceId ?? this.sourceId,
      type: type,
      quantity: quantity,
      unitPrice: unitPrice,
      total: total,
      date: date,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
