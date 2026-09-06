import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/models/cost_category_model.dart';

/// Drift-backed local data source for the `cost_category` read-through
/// cache — the P3 outlier with a BESPOKE syncer (see `cost_category_model.dart`
/// and `cost_category_syncer.dart`).
///
/// Unlike every other entity's local data source, this one has NO reactive
/// `watch*` stream: `CostCategoryBloc` is an app-wide singleton loaded as a
/// one-shot dependency dropdown on `input_page`/`activity_page`
/// (`GetCostCategoriesEvent`), never a primary page with a live list — so a
/// one-shot filtered read ([getCostCategories]) is all the flag-on repo
/// needs (see `CostCategoryRepositoryImpl`).
///
/// Satisfies [LocalSyncStore] so `CostCategorySyncer` can drive the local
/// mirror's create/delete push through the generic contract; the extra
/// filtered read ([getCostCategories]), the bespoke sync-state write
/// ([markSynced]), the full-re-fetch reconciler ([replaceAllFromServer]) and
/// [clear] sit outside that interface.
class CostCategoryLocalDataSource
    implements LocalSyncStore<CostCategoryModel> {
  CostCategoryLocalDataSource(this._db);

  final AppDatabase _db;

  /// One-shot local-mirror read, excluding local tombstones
  /// (`deletedLocally == true`), optionally filtered to a [type] and/or
  /// [category] — mirrors the server's `GET /api/v1/cost-categories`
  /// `?type&category` filters. Ordered by `name` ascending for a stable,
  /// human-friendly dropdown order (this entity's `createdAt` is synthetic
  /// — see `CostCategoryModel` — so ordering by it would be meaningless).
  Future<List<CostCategoryModel>> getCostCategories({
    String? type,
    String? category,
  }) async {
    final query = _db.select(_db.costCategories)
      ..where((row) => row.deletedLocally.equals(false));
    if (type != null) {
      query.where((row) => row.type.equals(type));
    }
    if (category != null) {
      query.where((row) => row.category.equals(category));
    }
    query.orderBy([(row) => OrderingTerm.asc(row.name)]);
    final rows = await query.get();
    return rows.map(CostCategoryModel.fromDrift).toList();
  }

  /// Inserts [model], or replaces the existing row sharing its `clientUuid`
  /// (the primary key) if one already exists.
  @override
  Future<void> upsert(CostCategoryModel model, {required bool pending}) {
    return _db
        .into(_db.costCategories)
        .insertOnConflictUpdate(model.toCompanion(pending: pending));
  }

  /// Marks the row for [clientUuid] as a tombstone awaiting delete-sync:
  /// `deletedLocally = true`, `pending = true`. The row is not removed —
  /// call [hardDelete] once the delete has synced with the server.
  @override
  Future<void> markDeleted(String clientUuid) {
    return (_db.update(
      _db.costCategories,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const CostCategoriesCompanion(
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
      _db.costCategories,
    )..where((row) => row.clientUuid.equals(clientUuid))).go();
  }

  /// Reconciles the row for [clientUuid] after a create/update syncs: sets
  /// [serverId] and clears `pending`. Part of the [LocalSyncStore] contract;
  /// NOT used by `CostCategorySyncer`'s bespoke create push (its `add`
  /// returns only a bool — see [markSynced]) — kept correct in case a future
  /// caller needs a real reconcile-by-server-id.
  @override
  Future<void> setServerId(
    String clientUuid,
    String serverId,
    DateTime updatedAt,
  ) {
    return (_db.update(
      _db.costCategories,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      CostCategoriesCompanion(
        serverId: Value(serverId),
        pending: const Value(false),
      ),
    );
  }

  /// Marks the row for [clientUuid] synced (`pending = false`) WITHOUT
  /// assigning a server id — used by `CostCategorySyncer.push` after a
  /// successful create, since the server's `addCostCategory` returns only a
  /// bool (never the created row/id). The real `serverId` is assigned later,
  /// when the next pull's [replaceAllFromServer] full re-fetch matches this
  /// category back up (by name/type/category) — see the syncer's docs for
  /// why that reconciliation gap is acceptable for this read-through cache.
  Future<void> markSynced(String clientUuid) {
    return (_db.update(
      _db.costCategories,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const CostCategoriesCompanion(pending: Value(false)),
    );
  }

  /// The category with the given [clientUuid], or `null` if no such row
  /// exists. Includes local tombstones (unlike [getCostCategories]).
  @override
  Future<CostCategoryModel?> getByClientUuid(String clientUuid) async {
    final row = await (_db.select(
      _db.costCategories,
    )..where((r) => r.clientUuid.equals(clientUuid))).getSingleOrNull();
    return row == null ? null : CostCategoryModel.fromDrift(row);
  }

  /// The category with the given server [serverId], or `null` if no such row
  /// exists.
  @override
  Future<CostCategoryModel?> getByServerId(String serverId) async {
    final row = await (_db.select(
      _db.costCategories,
    )..where((r) => r.serverId.equals(serverId))).getSingleOrNull();
    return row == null ? null : CostCategoryModel.fromDrift(row);
  }

  /// Full re-fetch reconciliation for `CostCategorySyncer.pull`: replaces
  /// every NON-pending local row with [serverRows] (a server row keyed
  /// deterministically as `'srv:' + serverId`, since the server never
  /// returns a client uuid of its own), while PRESERVING any row still
  /// `pending` — a local create/delete awaiting push that hasn't reached the
  /// server yet, so an unrelated full re-fetch must not clobber it.
  ///
  /// Runs inside one transaction so a mid-replace crash can't leave the
  /// mirror half-replaced. Idempotent: re-running with the same
  /// [serverRows] deletes-and-reinserts to the same final state.
  Future<void> replaceAllFromServer(
    List<CostCategoryModel> serverRows,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.costCategories,
      )..where((row) => row.pending.equals(false))).go();
      for (final server in serverRows) {
        final keyed = server.withSyncClientUuid('srv:${server.id}');
        await _db
            .into(_db.costCategories)
            .insertOnConflictUpdate(keyed.toCompanion(pending: false));
      }
    });
  }

  /// Deletes every row — used to wipe the local mirror on logout.
  Future<void> clear() => _db.delete(_db.costCategories).go();
}
