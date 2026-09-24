import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';

/// Rehydrates a model from a local drift row. The row's nullable
/// `serverId` becomes the model's `id` when present, else `''`
/// (mirroring the server-unknown placeholder used by `.create()`).
///
/// Also carries over the row's local sync-state flags (`pending`,
/// `deletedLocally`) — the sync pipeline (`RevenueSyncer`) needs them to
/// decide LWW / delete-wins outcomes on pull, since they otherwise only
/// live on the drift row, not on a bare [RevenueModel].
///
/// Split out of `revenue_model.dart` (web-console Task 5.6) so the model
/// class itself never imports `app_database.dart` — only mobile-only local
/// data sources import this file directly; the web console's DI container
/// never reaches it.
RevenueModel revenueModelFromDrift(RevenueRow row) {
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

/// Converts a [RevenueModel] into a drift insert/update companion for the
/// `Revenues` table. `serverId` is `null` while the server hasn't
/// assigned an `id` yet (i.e. `id` is empty).
extension RevenueModelDriftX on RevenueModel {
  RevenuesCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
    int farmId = 1,
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
      farmId: Value(farmId),
    );
  }
}
