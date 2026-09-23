import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';

/// Rehydrates a model from a local drift row. The row's nullable
/// `serverId` becomes the model's `id` when present, else `''`
/// (mirroring the server-unknown placeholder used by `.create()`).
///
/// Also carries over the row's local sync-state flags ([LandModel.pending],
/// [LandModel.deletedLocally]) — the sync pipeline (`LandSyncer`) needs them
/// to decide LWW / delete-wins outcomes on pull, since they otherwise only
/// live on the drift row, not on a bare [LandModel].
///
/// Split out of `land_model.dart` (web-console Task 5.6) so the model class
/// itself never imports `app_database.dart` — only mobile-only local data
/// sources import this file directly; the web console's DI container never
/// reaches it.
LandModel landModelFromDrift(LandRow row) {
  return LandModel(
    id: row.serverId ?? '',
    clientUuid: row.clientUuid,
    userId: row.userId,
    name: row.name,
    size: row.size,
    location: row.location,
    soilType: row.soilType,
    tenureType: row.tenureType,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    pending: row.pending,
    deletedLocally: row.deletedLocally,
  );
}

/// Converts a [LandModel] into a drift insert/update companion for the
/// `Lands` table. `serverId` is `null` while the server hasn't assigned an
/// `id` yet (i.e. `id` is empty).
extension LandModelDriftX on LandModel {
  LandsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
    int farmId = 1,
  }) {
    return LandsCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      name: Value(name),
      size: Value(size),
      location: Value(location),
      soilType: Value(soilType),
      tenureType: Value(tenureType),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
      farmId: Value(farmId),
    );
  }
}
