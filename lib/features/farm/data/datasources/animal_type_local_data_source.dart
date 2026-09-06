import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';

/// Drift-backed local data source for the animal_type feature.
///
/// Gives the animal_type feature reactive local reads ([watchAnimalTypes])
/// and local writes ([upsert], [markDeleted], [hardDelete], [setServerId])
/// over the `AnimalTypes` table, so the rest of the offline-first pipeline
/// (outbox/pull) can stage mutations before — and independently of —
/// syncing with the server. Every method keys rows by `clientUuid` (the
/// table's primary key), never by [AnimalTypeModel] value-equality (which
/// deliberately excludes `clientUuid` — see `AnimalTypeModel`'s
/// `Equatable.props`).
///
/// Satisfies [LocalSyncStore] so `BaseEntitySyncer<AnimalTypeModel>` can
/// drive the local mirror through the generic contract; the extra
/// reactive-read ([watchAnimalTypes]) and [clear] methods are
/// animal_type-specific and sit outside that interface.
class AnimalTypeLocalDataSource implements LocalSyncStore<AnimalTypeModel> {
  AnimalTypeLocalDataSource(this._db);

  final AppDatabase _db;

  /// Reactive stream of all animal types, excluding local tombstones
  /// (`deletedLocally == true`).
  ///
  /// Ordered by `createdAt` ascending (oldest first) — a stable order tied
  /// to when an animal type was first created locally, unaffected by later
  /// edits.
  Stream<List<AnimalTypeModel>> watchAnimalTypes() {
    final query = _db.select(_db.animalTypes)
      ..where((row) => row.deletedLocally.equals(false))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(AnimalTypeModel.fromDrift).toList(),
    );
  }

  /// Inserts [model], or replaces the existing row sharing its
  /// `clientUuid` (the primary key) if one already exists.
  @override
  Future<void> upsert(AnimalTypeModel model, {required bool pending}) {
    return _db
        .into(_db.animalTypes)
        .insertOnConflictUpdate(model.toCompanion(pending: pending));
  }

  /// Marks the row for [clientUuid] as a tombstone awaiting delete-sync:
  /// `deletedLocally = true`, `pending = true`. The row is not removed —
  /// call [hardDelete] once the delete has synced with the server.
  @override
  Future<void> markDeleted(String clientUuid) {
    return (_db.update(
      _db.animalTypes,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const AnimalTypesCompanion(
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
      _db.animalTypes,
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
      _db.animalTypes,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      AnimalTypesCompanion(
        serverId: Value(serverId),
        updatedAt: Value(updatedAt),
        pending: const Value(false),
      ),
    );
  }

  /// The animal type with the given [clientUuid], or `null` if no such row
  /// exists. Includes local tombstones (unlike [watchAnimalTypes]).
  @override
  Future<AnimalTypeModel?> getByClientUuid(String clientUuid) async {
    final row = await (_db.select(
      _db.animalTypes,
    )..where((r) => r.clientUuid.equals(clientUuid))).getSingleOrNull();
    return row == null ? null : AnimalTypeModel.fromDrift(row);
  }

  /// The animal type with the given server [serverId], or `null` if no such
  /// row exists.
  @override
  Future<AnimalTypeModel?> getByServerId(String serverId) async {
    final row = await (_db.select(
      _db.animalTypes,
    )..where((r) => r.serverId.equals(serverId))).getSingleOrNull();
    return row == null ? null : AnimalTypeModel.fromDrift(row);
  }

  /// Deletes every row — used to wipe the local mirror on logout.
  Future<void> clear() => _db.delete(_db.animalTypes).go();
}
