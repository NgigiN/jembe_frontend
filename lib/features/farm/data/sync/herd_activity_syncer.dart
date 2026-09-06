import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';

/// Bespoke [EntitySyncer] for `herd_activity` — NOT a
/// `BaseEntitySyncer<HerdActivityModel>`.
///
/// This entity is CREATE-ONLY (no list, no update, no delete) and has no
/// `updatedAt` of its own, so there is no last-writer-wins to do and nothing
/// to ever pull back:
///
/// - [push] `'create'`: fires the nested-URL create
///   (`POST /api/v1/herds/:herdId/activities`) and, on success, reconciles
///   the local row's server id (there is no `updatedAt` to reconcile — the
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
/// ### P4 follow-up (retry duplication risk)
/// `addHerdActivity`'s POST body (`HerdActivityModel.toJson`) carries no
/// `client_uuid` — the backend's herd_activity create endpoint isn't known
/// to be idempotent on one (unlike `land`/etc., which send it for exactly
/// this reason). If the engine retries a create push after a successful
/// server-side write but a lost response (e.g. the ack never reaches this
/// device), a duplicate activity could be created server-side. Left as-is
/// for P3 — flagged here as a P4/P5 follow-up, not blocking this rollout.
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
  Future<void> push(OutboxRow entry) async {
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

    final created = await _remote.addHerdActivity(model.herdId, model);
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
