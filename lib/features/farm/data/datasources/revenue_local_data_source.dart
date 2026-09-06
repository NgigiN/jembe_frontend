import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';

/// Drift-backed local data source for the revenue feature.
///
/// Gives the revenue feature reactive local reads ([watchRevenues]) and
/// local writes ([upsert], [markDeleted], [hardDelete], [setServerId]) over
/// the `Revenues` table, so the rest of the offline-first pipeline
/// (outbox/pull) can stage mutations before — and independently of —
/// syncing with the server. Every method keys rows by `clientUuid` (the
/// table's primary key), never by [RevenueModel] value-equality (which
/// deliberately excludes `clientUuid` — see `RevenueModel`'s
/// `Equatable.props`).
///
/// Satisfies [LocalSyncStore] so `BaseEntitySyncer<RevenueModel>` can drive
/// the local mirror through the generic contract; the extra reactive-read
/// ([watchRevenues]) and [clear] methods are revenue-specific and sit
/// outside that interface.
///
/// [watchRevenues] is deliberately UNFILTERED (see `RevenueBloc`'s R1 doc):
/// `RevenueBloc` is an app-wide singleton with a user-changeable
/// `source`/date filter, so a drift-level filtered watch would force a
/// cancel+re-subscribe on every filter change. Instead the bloc caches the
/// full list this stream emits and filters it in memory.
class RevenueLocalDataSource implements LocalSyncStore<RevenueModel> {
  RevenueLocalDataSource(this._db);

  final AppDatabase _db;

  /// Reactive stream of all revenues, excluding local tombstones
  /// (`deletedLocally == true`). UNFILTERED — see class docs.
  ///
  /// Ordered by `createdAt` ascending (oldest first) — a stable order tied
  /// to when a revenue was first recorded locally, unaffected by later
  /// edits.
  Stream<List<RevenueModel>> watchRevenues() {
    final query = _db.select(_db.revenues)
      ..where((row) => row.deletedLocally.equals(false))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(RevenueModel.fromDrift).toList(),
    );
  }

  /// Inserts [model], or replaces the existing row sharing its
  /// `clientUuid` (the primary key) if one already exists.
  @override
  Future<void> upsert(RevenueModel model, {required bool pending}) {
    return _db
        .into(_db.revenues)
        .insertOnConflictUpdate(model.toCompanion(pending: pending));
  }

  /// Marks the row for [clientUuid] as a tombstone awaiting delete-sync:
  /// `deletedLocally = true`, `pending = true`. The row is not removed —
  /// call [hardDelete] once the delete has synced with the server.
  @override
  Future<void> markDeleted(String clientUuid) {
    return (_db.update(
      _db.revenues,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const RevenuesCompanion(
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
      _db.revenues,
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
      _db.revenues,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      RevenuesCompanion(
        serverId: Value(serverId),
        updatedAt: Value(updatedAt),
        pending: const Value(false),
      ),
    );
  }

  /// The revenue with the given [clientUuid], or `null` if no such row
  /// exists. Includes local tombstones (unlike [watchRevenues]).
  @override
  Future<RevenueModel?> getByClientUuid(String clientUuid) async {
    final row = await (_db.select(
      _db.revenues,
    )..where((r) => r.clientUuid.equals(clientUuid))).getSingleOrNull();
    return row == null ? null : RevenueModel.fromDrift(row);
  }

  /// The revenue with the given server [serverId], or `null` if no such row
  /// exists.
  @override
  Future<RevenueModel?> getByServerId(String serverId) async {
    final row = await (_db.select(
      _db.revenues,
    )..where((r) => r.serverId.equals(serverId))).getSingleOrNull();
    return row == null ? null : RevenueModel.fromDrift(row);
  }

  /// Deletes every row — used to wipe the local mirror on logout.
  Future<void> clear() => _db.delete(_db.revenues).go();
}
