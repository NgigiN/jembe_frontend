import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';

/// Rehydrates a model from a local drift row. The row's nullable
/// `serverId` becomes the model's `id` when present, else `''`
/// (mirroring the server-unknown placeholder used by `.create()`).
///
/// Also carries over the row's local sync-state flags (`pending`,
/// `deletedLocally`) — the sync pipeline (`HarvestSyncer`) needs them to
/// decide LWW / delete-wins outcomes on pull, since they otherwise only
/// live on the drift row, not on a bare [HarvestModel].
///
/// Split out of `harvest_model.dart` (web-console Task 5.6) so the model
/// class itself never imports `app_database.dart` — only mobile-only local
/// data sources import this file directly; the web console's DI container
/// never reaches it.
HarvestModel harvestModelFromDrift(HarvestRow row) {
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

/// Converts a [HarvestModel] into a drift insert/update companion for the
/// `Harvests` table. `serverId` is `null` while the server hasn't
/// assigned an `id` yet (i.e. `id` is empty).
extension HarvestModelDriftX on HarvestModel {
  HarvestsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
    int farmId = 1,
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
      farmId: Value(farmId),
    );
  }
}
