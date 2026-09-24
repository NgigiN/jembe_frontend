import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';

/// Rehydrates a model from a local drift row. The row's nullable
/// `serverId` becomes the model's `id` when present, else `''`
/// (mirroring the server-unknown placeholder used by `.create()`).
///
/// Also carries over the row's local sync-state flags ([HerdModel.pending],
/// [HerdModel.deletedLocally]) — the sync pipeline (`HerdSyncer`) needs them
/// to decide LWW / delete-wins outcomes on pull, since they otherwise only
/// live on the drift row, not on a bare [HerdModel].
///
/// Split out of `herd_model.dart` (web-console Task 5.6) so the model class
/// itself never imports `app_database.dart` — only mobile-only local data
/// sources import this file directly; the web console's DI container never
/// reaches it.
HerdModel herdModelFromDrift(HerdRow row) {
  return HerdModel(
    id: row.serverId ?? '',
    clientUuid: row.clientUuid,
    userId: row.userId,
    name: row.name,
    animalTypeId: row.animalTypeId,
    location: row.location,
    initialHeadCount: row.initialHeadCount,
    currentHeadCount: row.currentHeadCount,
    startDate: row.startDate,
    endDate: row.endDate,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    pending: row.pending,
    deletedLocally: row.deletedLocally,
  );
}

/// Converts a [HerdModel] into a drift insert/update companion for the
/// `Herds` table. `serverId` is `null` while the server hasn't assigned an
/// `id` yet (i.e. `id` is empty). Unlike `HerdModel.toJson` (the wire body,
/// which omits the server-managed `current_head_count`), the local mirror
/// DOES track [HerdModel.currentHeadCount] — it's a real domain field the
/// app reads.
extension HerdModelDriftX on HerdModel {
  HerdsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
    int farmId = 1,
  }) {
    return HerdsCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      name: Value(name),
      animalTypeId: Value(animalTypeId),
      location: Value(location),
      initialHeadCount: Value(initialHeadCount),
      currentHeadCount: Value(currentHeadCount),
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
