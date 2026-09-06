import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';

/// Drift-backed local data source for the `herd_activity` create-only
/// offline outlier (see `herd_activity_model.dart` and
/// `herd_activity_syncer.dart`).
///
/// Unlike every other entity's local data source, this one has NO reactive
/// `watch*` stream: nothing in the app lists herd activities — the local
/// row exists only to durably hold a pending offline create until
/// `HerdActivitySyncer` pushes it, after which it just sits synced (there is
/// no read path that needs it back).
///
/// Satisfies [LocalSyncStore] so `HerdActivitySyncer` can drive the local
/// mirror's create push through the generic contract.
class HerdActivityLocalDataSource implements LocalSyncStore<HerdActivityModel> {
  HerdActivityLocalDataSource(this._db);

  final AppDatabase _db;

  /// Inserts [model], or replaces the existing row sharing its `clientUuid`
  /// (the primary key) if one already exists.
  @override
  Future<void> upsert(HerdActivityModel model, {required bool pending}) {
    return _db
        .into(_db.herdActivities)
        .insertOnConflictUpdate(model.toCompanion(pending: pending));
  }

  /// Marks the row for [clientUuid] as a tombstone. Part of the
  /// [LocalSyncStore] contract; not exercised in practice — this entity has
  /// no delete path (create-only), so nothing ever calls this today.
  @override
  Future<void> markDeleted(String clientUuid) {
    return (_db.update(
      _db.herdActivities,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const HerdActivitiesCompanion(
        deletedLocally: Value(true),
        pending: Value(true),
      ),
    );
  }

  /// Physically removes the row for [clientUuid] — used by
  /// `DeletionsDataSource` should the server ever emit a herd_activity
  /// tombstone (it doesn't today — see `DeletionsDataSource.stores` docs).
  @override
  Future<void> hardDelete(String clientUuid) {
    return (_db.delete(
      _db.herdActivities,
    )..where((row) => row.clientUuid.equals(clientUuid))).go();
  }

  /// Reconciles the row for [clientUuid] after a create syncs: sets
  /// [serverId] and [updatedAt] (synthesized from the created row's
  /// `createdAt` — see `HerdActivitySyncer.push`), and clears `pending`.
  @override
  Future<void> setServerId(
    String clientUuid,
    String serverId,
    DateTime updatedAt,
  ) {
    return (_db.update(
      _db.herdActivities,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      HerdActivitiesCompanion(
        serverId: Value(serverId),
        updatedAt: Value(updatedAt),
        pending: const Value(false),
      ),
    );
  }

  /// The activity with the given [clientUuid], or `null` if no such row
  /// exists. Includes local tombstones (none in practice — see
  /// [markDeleted]).
  @override
  Future<HerdActivityModel?> getByClientUuid(String clientUuid) async {
    final row = await (_db.select(
      _db.herdActivities,
    )..where((r) => r.clientUuid.equals(clientUuid))).getSingleOrNull();
    return row == null ? null : HerdActivityModel.fromDrift(row);
  }

  /// The activity with the given server [serverId], or `null` if no such
  /// row exists.
  @override
  Future<HerdActivityModel?> getByServerId(String serverId) async {
    final row = await (_db.select(
      _db.herdActivities,
    )..where((r) => r.serverId.equals(serverId))).getSingleOrNull();
    return row == null ? null : HerdActivityModel.fromDrift(row);
  }

  /// Deletes every row — used to wipe the local mirror on logout.
  Future<void> clear() => _db.delete(_db.herdActivities).go();
}
