import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';

/// Drift-backed local data source for the harvest feature.
///
/// Gives the harvest feature reactive local reads ([watchHarvests]) and
/// local writes ([upsert], [markDeleted], [hardDelete], [setServerId]) over
/// the `Harvests` table, so the rest of the offline-first pipeline
/// (outbox/pull) can stage mutations before — and independently of —
/// syncing with the server. Every method keys rows by `clientUuid` (the
/// table's primary key), never by [HarvestModel] value-equality (which
/// deliberately excludes `clientUuid` — see `HarvestModel`'s
/// `Equatable.props`).
///
/// Satisfies [LocalSyncStore] so `BaseEntitySyncer<HarvestModel>` can drive
/// the local mirror through the generic contract; the extra reactive-read
/// ([watchHarvests]) and [clear] methods are harvest-specific and sit
/// outside that interface.
class HarvestLocalDataSource implements LocalSyncStore<HarvestModel> {
  HarvestLocalDataSource(this._db);

  final AppDatabase _db;

  /// Reactive stream of harvests, excluding local tombstones
  /// (`deletedLocally == true`), optionally filtered to a single [seasonId]
  /// — mirrors `harvest_page.dart`'s existing `GetHarvestsEvent(seasonId:)`
  /// scoped list.
  ///
  /// Ordered by `createdAt` ascending (oldest first) — a stable order tied
  /// to when a harvest was first created locally, unaffected by later edits.
  ///
  /// FK note: [seasonId] matches the value stored in the local row's
  /// `seasonId` column, which tracks the parent season's CURRENT local
  /// identity — its `client_uuid` while the season is still unsynced, its
  /// numeric server-id once the season syncs. That flip is kept in lockstep
  /// by `SeasonLocalDataSource.setServerId`, which — in the same transaction
  /// as the season's own reconcile — rewrites every child harvest's
  /// `seasonId` from the season's client_uuid to its new server-id (P5). So
  /// filtering by the season's client_uuid matches while both are offline,
  /// and filtering by the season's server-id matches the instant the season
  /// syncs — without waiting for the harvest's own push, or a later pull, to
  /// reconcile the row.
  Stream<List<HarvestModel>> watchHarvests({String? seasonId}) {
    final query = _db.select(_db.harvests)
      ..where((row) => row.deletedLocally.equals(false));
    if (seasonId != null && seasonId.isNotEmpty) {
      query.where((row) => row.seasonId.equals(seasonId));
    }
    query.orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(HarvestModel.fromDrift).toList(),
    );
  }

  /// Inserts [model], or replaces the existing row sharing its
  /// `clientUuid` (the primary key) if one already exists.
  @override
  Future<void> upsert(HarvestModel model, {required bool pending}) {
    return _db
        .into(_db.harvests)
        .insertOnConflictUpdate(model.toCompanion(pending: pending));
  }

  /// Marks the row for [clientUuid] as a tombstone awaiting delete-sync:
  /// `deletedLocally = true`, `pending = true`. The row is not removed —
  /// call [hardDelete] once the delete has synced with the server.
  @override
  Future<void> markDeleted(String clientUuid) {
    return (_db.update(
      _db.harvests,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const HarvestsCompanion(
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
      _db.harvests,
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
      _db.harvests,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      HarvestsCompanion(
        serverId: Value(serverId),
        updatedAt: Value(updatedAt),
        pending: const Value(false),
      ),
    );
  }

  /// The harvest with the given [clientUuid], or `null` if no such row
  /// exists. Includes local tombstones (unlike [watchHarvests]).
  @override
  Future<HarvestModel?> getByClientUuid(String clientUuid) async {
    final row = await (_db.select(
      _db.harvests,
    )..where((r) => r.clientUuid.equals(clientUuid))).getSingleOrNull();
    return row == null ? null : HarvestModel.fromDrift(row);
  }

  /// The harvest with the given server [serverId], or `null` if no such row
  /// exists.
  @override
  Future<HarvestModel?> getByServerId(String serverId) async {
    final row = await (_db.select(
      _db.harvests,
    )..where((r) => r.serverId.equals(serverId))).getSingleOrNull();
    return row == null ? null : HarvestModel.fromDrift(row);
  }

  /// Deletes every row — used to wipe the local mirror on logout.
  Future<void> clear() => _db.delete(_db.harvests).go();
}
