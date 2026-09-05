import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';

/// Bespoke [EntitySyncer] for the `cost_category` read-through cache — NOT a
/// `BaseEntitySyncer<CostCategoryModel>`.
///
/// This entity has no real timestamps (see `CostCategoryModel`'s docs), so
/// there is no last-writer-wins to do on pull, and its create endpoint
/// returns a bare `bool` — never the created row/server id — so there is no
/// id to reconcile the way every other entity's push does. Instead:
///
/// - [push] `'create'`: fires the create (with `client_uuid` in the POST
///   body for P1 idempotency), then, on success, marks the local row synced
///   (`pending = false`) WITHOUT a server id — [CostCategoryLocalDataSource
///   .markSynced], not `setServerId`.
/// - [push] `'delete'`: deletes server-side (only if a server id was ever
///   learned), then hard-deletes the local tombstone.
/// - [push] `'update'`: no-op — `cost_category` has no update.
/// - [pull]: a FULL, unfiltered re-fetch EVERY time (never a delta) that
///   replaces every non-pending local row and re-keys each server row's
///   clientUuid deterministically as `'srv:' + serverId` (the server never
///   echoes one back). This is also where a create's real server id finally
///   lands locally: the clientUuid minted by `.create()` is superseded by
///   the `'srv:...'`-keyed row the next full re-fetch upserts. Always
///   returns `null` — there is no meaningful cursor (no `updatedAt`), and a
///   null return keeps the engine from ever expecting a delta pull for this
///   entity.
///
/// `NetworkException`/`ServerException` thrown by [_remote] are deliberately
/// left to propagate out of [push]/[pull] — the engine's push/pull error
/// matrix (see `entity_syncer.dart`) handles them; this class never
/// catches-and-swallows them.
class CostCategorySyncer implements EntitySyncer {
  CostCategorySyncer({
    required CostCategoryRemoteDataSource remote,
    required CostCategoryLocalDataSource local,
  }) : _remote = remote,
       _local = local;

  final CostCategoryRemoteDataSource _remote;
  final CostCategoryLocalDataSource _local;

  @override
  String get entity => 'cost_category';

  @override
  Future<void> push(OutboxRow entry) async {
    if (entry.op == 'create') {
      await _pushCreate(entry.clientUuid);
    } else if (entry.op == 'delete') {
      await _pushDelete(entry.clientUuid);
    }
    // 'update' (and any op outside the {'create','delete'} contract this
    // entity actually uses): nothing to do — cost_category has no update.
  }

  Future<void> _pushCreate(String clientUuid) async {
    final model = await _local.getByClientUuid(clientUuid);
    if (model == null) {
      // Row is gone (e.g. created-then-deleted offline, annihilated out of
      // the outbox already) — nothing left to push.
      return;
    }

    final success = await _remote.addCostCategory(
      name: model.name,
      type: model.type,
      category: model.category,
      clientUuid: clientUuid,
    );
    if (success) {
      // No created row/server id comes back (see class docs) — just clear
      // `pending`. The real serverId lands later via the next pull's full
      // re-fetch (`CostCategoryLocalDataSource.replaceAllFromServer`).
      await _local.markSynced(clientUuid);
    }
    // `false` is not actually reachable in practice — the remote data
    // source only ever returns `true` on a 200/201 and throws
    // `ServerException` otherwise — left as a no-op rather than guessed at.
  }

  Future<void> _pushDelete(String clientUuid) async {
    final model = await _local.getByClientUuid(clientUuid);
    final serverId = model?.syncServerId ?? '';

    if (serverId.isNotEmpty) {
      await _remote.deleteCostCategory(serverId);
    }
    // Else: never synced (no server id) — nothing to delete server-side;
    // this shouldn't normally happen since create+delete annihilate in the
    // outbox, but is handled defensively.

    await _local.hardDelete(clientUuid);
  }

  @override
  Future<DateTime?> pull(DateTime? since) async {
    // UNFILTERED, no `updatedSince` — see class docs: this entity has no
    // timestamps to delta against, so every pull is a full re-fetch.
    final serverRows = await _remote.getCostCategories();
    await _local.replaceAllFromServer(serverRows);
    return null;
  }
}
