import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';

/// Drift-backed local data source for the season feature.
///
/// Gives the season feature reactive local reads ([watchSeasons]) and local
/// writes ([upsert], [markDeleted], [hardDelete], [setServerId]) over the
/// `Seasons` table, so the rest of the offline-first pipeline (outbox/pull)
/// can stage mutations before — and independently of — syncing with the
/// server. Every method keys rows by `clientUuid` (the table's primary
/// key), never by [SeasonModel] value-equality (which deliberately excludes
/// `clientUuid` — see `SeasonModel`'s `Equatable.props`).
///
/// Satisfies [LocalSyncStore] so `BaseEntitySyncer<SeasonModel>` can drive
/// the local mirror through the generic contract; the extra reactive-read
/// ([watchSeasons]) and [clear] methods are season-specific and sit outside
/// that interface.
class SeasonLocalDataSource implements LocalSyncStore<SeasonModel> {
  SeasonLocalDataSource(this._db);

  final AppDatabase _db;

  /// Reactive stream of all seasons, excluding local tombstones
  /// (`deletedLocally == true`).
  ///
  /// Ordered by `createdAt` ascending (oldest first) — a stable order tied
  /// to when a season was first created locally, unaffected by later edits.
  Stream<List<SeasonModel>> watchSeasons() {
    final query = _db.select(_db.seasons)
      ..where((row) => row.deletedLocally.equals(false))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(SeasonModel.fromDrift).toList(),
    );
  }

  /// Inserts [model], or replaces the existing row sharing its
  /// `clientUuid` (the primary key) if one already exists.
  @override
  Future<void> upsert(SeasonModel model, {required bool pending}) {
    return _db
        .into(_db.seasons)
        .insertOnConflictUpdate(model.toCompanion(pending: pending));
  }

  /// Marks the row for [clientUuid] as a tombstone awaiting delete-sync:
  /// `deletedLocally = true`, `pending = true`. The row is not removed —
  /// call [hardDelete] once the delete has synced with the server.
  @override
  Future<void> markDeleted(String clientUuid) {
    return (_db.update(
      _db.seasons,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const SeasonsCompanion(
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
      _db.seasons,
    )..where((row) => row.clientUuid.equals(clientUuid))).go();
  }

  /// Reconciles the row for [clientUuid] after a create/update syncs: sets
  /// [serverId] and [updatedAt], and clears `pending`.
  ///
  /// Also cascades one step of FK reconciliation (P5): any local harvest row
  /// still carrying this season's `clientUuid` in its `seasonId` FK is
  /// rewritten to the new [serverId], in the SAME transaction as the season's
  /// own reconcile. A harvest created offline under a not-yet-synced season
  /// stores the season's `client_uuid` as its local `seasonId`;
  /// `HarvestLocalDataSource.watchHarvests(seasonId:)` is the one place in the
  /// app that filters rows by that FK. Unless the child row is flipped to the
  /// server-id the instant the season gains one, a
  /// `watchHarvests(seasonId: <season server-id>)` would miss the harvest
  /// until the harvest's OWN push + pull-back happened to reconcile the row —
  /// and that window stays open across a partial sync (e.g. the season pushes,
  /// then a transient failure skips the pull phase, or the harvest is still
  /// queued). Rewriting here closes it at the moment the parent syncs,
  /// independent of the child's push state.
  ///
  /// The cascade is pure FK reconciliation: it leaves the harvest's
  /// `pending`/`updatedAt` untouched, so it enqueues no spurious push and
  /// never disturbs last-writer-wins. It is idempotent — a numeric `seasonId`
  /// can never equal a uuid `clientUuid`, so re-running on an
  /// already-reconciled child matches nothing. Sharing one transaction keeps
  /// the two tables consistent: a reader can never observe the season bearing
  /// its server-id while a child harvest still points at the stale
  /// client_uuid. (Harvest is the ONLY entity with a local FK-equality filter,
  /// so no other child table needs this.)
  @override
  Future<void> setServerId(
    String clientUuid,
    String serverId,
    DateTime updatedAt,
  ) {
    return _db.transaction(() async {
      await (_db.update(
        _db.seasons,
      )..where((row) => row.clientUuid.equals(clientUuid))).write(
        SeasonsCompanion(
          serverId: Value(serverId),
          updatedAt: Value(updatedAt),
          pending: const Value(false),
        ),
      );

      await (_db.update(
        _db.harvests,
      )..where((row) => row.seasonId.equals(clientUuid))).write(
        HarvestsCompanion(seasonId: Value(serverId)),
      );
    });
  }

  /// The season with the given [clientUuid], or `null` if no such row
  /// exists. Includes local tombstones (unlike [watchSeasons]).
  @override
  Future<SeasonModel?> getByClientUuid(String clientUuid) async {
    final row = await (_db.select(
      _db.seasons,
    )..where((r) => r.clientUuid.equals(clientUuid))).getSingleOrNull();
    return row == null ? null : SeasonModel.fromDrift(row);
  }

  /// The season with the given server [serverId], or `null` if no such row
  /// exists.
  @override
  Future<SeasonModel?> getByServerId(String serverId) async {
    final row = await (_db.select(
      _db.seasons,
    )..where((r) => r.serverId.equals(serverId))).getSingleOrNull();
    return row == null ? null : SeasonModel.fromDrift(row);
  }

  /// Deletes every row — used to wipe the local mirror on logout.
  Future<void> clear() => _db.delete(_db.seasons).go();
}
