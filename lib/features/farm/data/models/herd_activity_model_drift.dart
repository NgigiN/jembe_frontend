import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';

/// Rehydrates a model from a local drift row. The row's nullable
/// `serverId` becomes the model's `id` when present, else `''` (mirroring
/// the server-unknown placeholder used by `.create()`). The row also stores
/// `herdId` — the syncer needs it to build the nested
/// `/herds/:herdId/activities` push URL.
///
/// Carries over the row's local sync-state flags
/// ([HerdActivityModel.pending], [HerdActivityModel.deletedLocally]); the
/// row's `updated_at` column is deliberately NOT carried over — see
/// `HerdActivityModel`'s class docs: it is synthesized fresh from
/// `createdAt` wherever needed, never round-tripped.
///
/// Split out of `herd_activity_model.dart` (web-console Task 5.6) so the
/// model class itself never imports `app_database.dart` — only mobile-only
/// local data sources import this file directly; the web console's DI
/// container never reaches it.
HerdActivityModel herdActivityModelFromDrift(HerdActivityRow row) {
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

/// Converts a [HerdActivityModel] into a drift insert/update companion for
/// the `HerdActivities` table. `serverId` is `null` while the server hasn't
/// assigned an `id` yet (i.e. `id` is empty). `updatedAt` is SYNTHETIC — set
/// to `createdAt` (see `HerdActivityModel`'s class docs) since this entity
/// has no real `updatedAt` of its own.
extension HerdActivityModelDriftX on HerdActivityModel {
  HerdActivitiesCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
    int farmId = 1,
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
      farmId: Value(farmId),
    );
  }
}
