import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';

/// Rehydrates a model from a local drift row. The row's nullable
/// `serverId` becomes the model's `id` when present, else `''`
/// (mirroring the server-unknown placeholder used by `.create()`).
///
/// Also carries over the row's local sync-state flags ([SeasonModel.pending],
/// [SeasonModel.deletedLocally]) — the sync pipeline (`SeasonSyncer`) needs
/// them to decide LWW / delete-wins outcomes on pull, since they otherwise
/// only live on the drift row, not on a bare [SeasonModel].
///
/// Split out of `season_model.dart` (web-console Task 5.6) so the model
/// class itself never imports `app_database.dart` — only mobile-only local
/// data sources import this file directly; the web console's DI container
/// never reaches it.
SeasonModel seasonModelFromDrift(SeasonRow row) {
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

/// Converts a [SeasonModel] into a drift insert/update companion for the
/// `Seasons` table. `serverId` is `null` while the server hasn't assigned an
/// `id` yet (i.e. `id` is empty).
extension SeasonModelDriftX on SeasonModel {
  SeasonsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
    int farmId = 1,
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
      farmId: Value(farmId),
    );
  }
}
