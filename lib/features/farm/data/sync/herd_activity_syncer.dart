import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/sync/fk_translators.dart';

/// Bespoke [EntitySyncer] for `herd_activity` — NOT a
/// `BaseEntitySyncer<HerdActivityModel>`.
///
/// This entity is CREATE-ONLY (no list, no update, no delete) and has no
/// `updatedAt` of its own, so there is no last-writer-wins to do and nothing
/// to ever pull back:
///
/// - [push] `'create'`: translates `HerdActivityModel.herdId` (the herd's
///   `client_uuid` while the herd is unsynced) to the herd's SERVER id via
///   [resolveFkOrThrow] — this throws `SyncDependencyException` (parks the
///   push for a later pass) when the herd hasn't synced yet — then fires the
///   nested-URL create (`POST /api/v1/herds/:herdId/activities`) with the
///   resolved server id and, on success, records the created id with the
///   [FkResolver] (so a same-pass child can resolve it) and reconciles the
///   local row's server id (there is no `updatedAt` to reconcile — the
///   created row's `createdAt` is reused to satisfy [HerdActivityLocalDataSource
///   .setServerId]'s signature).
/// - [push] any other op (`'update'`/`'delete'`): no-op — this entity never
///   enqueues either (create-only).
/// - [pull]: NO-OP, always returns `null` — nothing in the app lists herd
///   activities, so there is nothing to fetch back and reconcile.
///
/// `NetworkException`/`ServerException` thrown by [_remote] are deliberately
/// left to propagate out of [push] — the engine's push error matrix (see
/// `entity_syncer.dart`) handles them; this class never catches-and-swallows
/// them.
///
/// ### P4 (resolved)
/// `addHerdActivity`'s POST body now spreads `client_uuid`
/// (`HerdActivityRemoteDataSource.addHerdActivity`), matching every other
/// entity's create body — the backend dedupes herd_activity creates on
/// `(herd_id, client_uuid)`, so a retried push after a lost ack no longer
/// risks a duplicate server-side row.
class HerdActivitySyncer implements EntitySyncer {
  HerdActivitySyncer({
    required HerdActivityRemoteDataSource remote,
    required HerdActivityLocalDataSource local,
  }) : _remote = remote,
       _local = local;

  final HerdActivityRemoteDataSource _remote;
  final HerdActivityLocalDataSource _local;

  @override
  String get entity => 'herd_activity';

  // This entity's [pull] always returns `null` (see its docs) — it never
  // advances a cursor. Cursorless: excluded from the engine's
  // deletions-replay cursor computation (`SyncEngine._pullPhase`) so this
  // entity's perpetual-null cursor doesn't force an unbounded full
  // `/sync/deletions` replay on every pass for every OTHER entity too.
  @override
  bool get hasCursor => false;

  @override
  Future<void> push(OutboxRow entry, FkResolver resolver) async {
    if (entry.op != 'create') {
      // 'update'/'delete': never enqueued for this entity (create-only) —
      // nothing to do.
      return;
    }

    final model = await _local.getByClientUuid(entry.clientUuid);
    if (model == null) {
      // Row is gone — nothing left to push.
      return;
    }

    // FK: the nested create URL needs the herd's SERVER id. `model.herdId` is
    // the herd's client_uuid while the herd is unsynced — translate it (parks
    // via SyncDependencyException when the herd hasn't synced yet).
    final herdServerId = await resolveFkOrThrow(resolver, 'herd', model.herdId);

    final created = await _remote.addHerdActivity(herdServerId, model);
    resolver.record(entity, entry.clientUuid, created.id);
    await _local.setServerId(entry.clientUuid, created.id, created.createdAt);
  }

  @override
  Future<DateTime?> pull(DateTime? since) async {
    // NO-OP: nothing in the app lists herd activities, so there is nothing
    // to fetch back and reconcile against the local mirror — see class
    // docs. Always returns `null` (no cursor).
    return null;
  }
}
