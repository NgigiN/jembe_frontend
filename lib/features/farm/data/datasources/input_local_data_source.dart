import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';

/// Drift-backed local data source for the input feature.
///
/// Gives the input feature reactive local reads ([watchInputs]) and local
/// writes ([upsert], [markDeleted], [hardDelete], [setServerId]) over the
/// `Inputs` table, so the rest of the offline-first pipeline (outbox/pull)
/// can stage mutations before — and independently of — syncing with the
/// server. Every method keys rows by `clientUuid` (the table's primary
/// key), never by [InputModel] value-equality (which deliberately excludes
/// `clientUuid` — see `InputModel`'s `Equatable.props`).
///
/// Satisfies [LocalSyncStore] so `BaseEntitySyncer<InputModel>` can drive
/// the local mirror through the generic contract; the extra reactive-read
/// ([watchInputs]) and [clear] methods are input-specific and sit outside
/// that interface.
class InputLocalDataSource implements LocalSyncStore<InputModel> {
  InputLocalDataSource(this._db);

  final AppDatabase _db;

  /// Reactive stream of inputs, excluding local tombstones
  /// (`deletedLocally == true`), optionally filtered to a single
  /// [sourceType] — mirrors `input_page.dart`'s existing
  /// `GetInputsEvent(sourceType:)` scoped list. `sourceType` is a stable
  /// string discriminator ('plant'/'animal'/…), not a parent id, so this
  /// filter has no clientUuid concern (unlike the `animalId`/`sourceId`
  /// FK — see `InputModel`'s notes on `.create()`).
  ///
  /// Ordered by `createdAt` ascending (oldest first) — a stable order tied
  /// to when an input was first created locally, unaffected by later edits.
  Stream<List<InputModel>> watchInputs({String? sourceType}) {
    final query = _db.select(_db.inputs)
      ..where((row) => row.deletedLocally.equals(false));
    if (sourceType != null && sourceType.isNotEmpty) {
      query.where((row) => row.sourceType.equals(sourceType));
    }
    query.orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(InputModel.fromDrift).toList(),
    );
  }

  /// Inserts [model], or replaces the existing row sharing its
  /// `clientUuid` (the primary key) if one already exists.
  @override
  Future<void> upsert(InputModel model, {required bool pending}) {
    return _db
        .into(_db.inputs)
        .insertOnConflictUpdate(model.toCompanion(pending: pending));
  }

  /// Marks the row for [clientUuid] as a tombstone awaiting delete-sync:
  /// `deletedLocally = true`, `pending = true`. The row is not removed —
  /// call [hardDelete] once the delete has synced with the server.
  @override
  Future<void> markDeleted(String clientUuid) {
    return (_db.update(
      _db.inputs,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const InputsCompanion(
        deletedLocally: Value(true),
        pending: Value(true),
      ),
    );
  }

  /// Physically removes the row for [clientUuid] — call once a delete has
  /// synced with the server.
  @override
  Future<void> hardDelete(String clientUuid) {
    return (_db.delete(
      _db.inputs,
    )..where((row) => row.clientUuid.equals(clientUuid))).go();
  }

  /// Reconciles the row for [clientUuid] after a create/update syncs: sets
  /// [serverId] and [updatedAt], and clears `pending`.
  @override
  Future<void> setServerId(
    String clientUuid,
    String serverId,
    DateTime updatedAt,
  ) {
    return (_db.update(
      _db.inputs,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      InputsCompanion(
        serverId: Value(serverId),
        updatedAt: Value(updatedAt),
        pending: const Value(false),
      ),
    );
  }

  /// The input with the given [clientUuid], or `null` if no such row
  /// exists. Includes local tombstones (unlike [watchInputs]).
  @override
  Future<InputModel?> getByClientUuid(String clientUuid) async {
    final row = await (_db.select(
      _db.inputs,
    )..where((r) => r.clientUuid.equals(clientUuid))).getSingleOrNull();
    return row == null ? null : InputModel.fromDrift(row);
  }

  /// The input with the given server [serverId], or `null` if no such row
  /// exists.
  @override
  Future<InputModel?> getByServerId(String serverId) async {
    final row = await (_db.select(
      _db.inputs,
    )..where((r) => r.serverId.equals(serverId))).getSingleOrNull();
    return row == null ? null : InputModel.fromDrift(row);
  }

  /// Deletes every row — used to wipe the local mirror on logout.
  Future<void> clear() => _db.delete(_db.inputs).go();
}
