import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';

/// Rehydrates a model from a local drift row. The row's nullable
/// `serverId` becomes the model's `id` when present, else `''`
/// (mirroring the server-unknown placeholder used by `.create()`).
///
/// Also carries over the row's local sync-state flags
/// ([AnimalTypeModel.pending], [AnimalTypeModel.deletedLocally]) — the sync
/// pipeline (`AnimalTypeSyncer`) needs them to decide LWW / delete-wins
/// outcomes on pull, since they otherwise only live on the drift row, not on
/// a bare [AnimalTypeModel].
///
/// Split out of `animal_type_model.dart` (web-console Task 5.6) so the model
/// class itself never imports `app_database.dart` — only mobile-only local
/// data sources import this file directly; the web console's DI container
/// never reaches it.
AnimalTypeModel animalTypeModelFromDrift(AnimalTypeRow row) {
  return AnimalTypeModel(
    id: row.serverId ?? '',
    clientUuid: row.clientUuid,
    userId: row.userId,
    name: row.name,
    notes: row.notes,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    pending: row.pending,
    deletedLocally: row.deletedLocally,
  );
}

/// Converts an [AnimalTypeModel] into a drift insert/update companion for
/// the `AnimalTypes` table. `serverId` is `null` while the server hasn't
/// assigned an `id` yet (i.e. `id` is empty).
extension AnimalTypeModelDriftX on AnimalTypeModel {
  AnimalTypesCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
    int farmId = 1,
  }) {
    return AnimalTypesCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      name: Value(name),
      notes: Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
      farmId: Value(farmId),
    );
  }
}
