import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';

/// Drift-backed local data source for the land feature.
///
/// Gives the land feature reactive local reads ([watchLands]) and local
/// writes ([upsert], [markDeleted], [hardDelete], [setServerId]) over the
/// `Lands` table, so the rest of the offline-first pipeline (outbox/pull)
/// can stage mutations before — and independently of — syncing with the
/// server. Every method keys rows by `clientUuid` (the table's primary
/// key), never by [LandModel] value-equality (which deliberately excludes
/// `clientUuid` — see `LandModel`'s `Equatable.props`).
class LandLocalDataSource {
  LandLocalDataSource(this._db);

  final AppDatabase _db;

  /// Reactive stream of all lands, excluding local tombstones
  /// (`deletedLocally == true`).
  ///
  /// Ordered by `createdAt` ascending (oldest first) — a stable order tied
  /// to when a land was first created locally, unaffected by later edits.
  Stream<List<LandModel>> watchLands() {
    final query = _db.select(_db.lands)
      ..where((row) => row.deletedLocally.equals(false))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(LandModel.fromDrift).toList(),
    );
  }

  /// Inserts [model], or replaces the existing row sharing its
  /// `clientUuid` (the primary key) if one already exists.
  Future<void> upsert(LandModel model, {required bool pending}) {
    return _db
        .into(_db.lands)
        .insertOnConflictUpdate(model.toCompanion(pending: pending));
  }

  /// Marks the row for [clientUuid] as a tombstone awaiting delete-sync:
  /// `deletedLocally = true`, `pending = true`. The row is not removed —
  /// call [hardDelete] once the delete has synced with the server.
  Future<void> markDeleted(String clientUuid) {
    return (_db.update(
      _db.lands,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const LandsCompanion(deletedLocally: Value(true), pending: Value(true)),
    );
  }

  /// Physically removes the row for [clientUuid] — call once a delete has
  /// synced with the server.
  Future<void> hardDelete(String clientUuid) {
    return (_db.delete(
      _db.lands,
    )..where((row) => row.clientUuid.equals(clientUuid))).go();
  }

  /// Reconciles the row for [clientUuid] after a create/update syncs: sets
  /// [serverId] and [updatedAt], and clears `pending`.
  Future<void> setServerId(
    String clientUuid,
    String serverId,
    DateTime updatedAt,
  ) {
    return (_db.update(
      _db.lands,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      LandsCompanion(
        serverId: Value(serverId),
        updatedAt: Value(updatedAt),
        pending: const Value(false),
      ),
    );
  }

  /// The land with the given [clientUuid], or `null` if no such row
  /// exists. Includes local tombstones (unlike [watchLands]).
  Future<LandModel?> getByClientUuid(String clientUuid) async {
    final row = await (_db.select(
      _db.lands,
    )..where((r) => r.clientUuid.equals(clientUuid))).getSingleOrNull();
    return row == null ? null : LandModel.fromDrift(row);
  }

  /// The land with the given server [serverId], or `null` if no such row
  /// exists.
  Future<LandModel?> getByServerId(String serverId) async {
    final row = await (_db.select(
      _db.lands,
    )..where((r) => r.serverId.equals(serverId))).getSingleOrNull();
    return row == null ? null : LandModel.fromDrift(row);
  }

  /// Deletes every row — used to wipe the local mirror on logout.
  Future<void> clear() => _db.delete(_db.lands).go();
}
