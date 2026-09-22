import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';

/// Rehydrates a model from a local drift row. The row's nullable
/// `serverId` becomes the model's `id` when present, else `''`
/// (mirroring the server-unknown placeholder used by `.create()`).
///
/// Also carries over the row's local sync-state flags (`pending`,
/// `deletedLocally`) — the sync pipeline (`InputSyncer`) needs them to
/// decide LWW / delete-wins outcomes on pull, since they otherwise only
/// live on the drift row, not on a bare [InputModel].
///
/// Split out of `input_model.dart` (web-console Task 5.6) so the model
/// class itself never imports `app_database.dart` — only mobile-only local
/// data sources import this file directly; the web console's DI container
/// never reaches it.
InputModel inputModelFromDrift(InputRow row) {
  return InputModel(
    id: row.serverId ?? '',
    clientUuid: row.clientUuid,
    sourceType: row.sourceType,
    sourceId: row.sourceId,
    animalId: row.animalId,
    type: row.type,
    quantity: row.quantity,
    cost: row.cost,
    date: row.date,
    notes: row.notes,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    pending: row.pending,
    deletedLocally: row.deletedLocally,
  );
}

/// Converts an [InputModel] into a drift insert/update companion for the
/// `Inputs` table. `serverId` is `null` while the server hasn't assigned
/// an `id` yet (i.e. `id` is empty).
extension InputModelDriftX on InputModel {
  InputsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
    int farmId = 1,
  }) {
    return InputsCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      sourceType: Value(sourceType),
      sourceId: Value(sourceId),
      animalId: Value(animalId),
      type: Value(type),
      quantity: Value(quantity),
      cost: Value(cost),
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
