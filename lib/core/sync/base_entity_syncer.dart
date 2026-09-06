import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';

/// Reusable [EntitySyncer] for any entity whose model is a [SyncableModel].
///
/// This is the `land` pilot's proven syncer generalized: the push dispatch
/// (create/update/delete + server-id reconcile), the pull loop, and the
/// `_applyPulledRow` reconciler (delete-wins + instant-based last-writer-wins,
/// plus the client_uuid ↔ server_id fallback) are moved here VERBATIM in
/// structure, parameterized by a [RemoteSyncAdapter] + [LocalSyncStore] and the
/// [SyncableModel] getters. The 10 CRUD entities in P3 inherit this one
/// tested implementation instead of copying ~150 subtle lines each.
///
/// Owns no retry/backoff/ordering logic — that's `SyncEngine`'s job; this
/// class only ever does ONE thing per call: apply one outbox entry, or
/// pull-and-reconcile every page of server changes since the last cursor
/// (the backend caps a single list response at 500 rows ordered
/// `updated_at ASC, id ASC` whenever `updated_since` is present, so [pull]
/// loops, re-querying from the last page's max `updatedAt`, until a pass
/// makes no further forward progress — see [pull]'s doc comment).
///
/// `NetworkException`/`ServerException` thrown by the remote adapter are
/// deliberately left to propagate out of [push]/[pull] — the engine's
/// push/pull error matrix (see `entity_syncer.dart`) handles them. This class
/// never catches-and-swallows them.
class BaseEntitySyncer<M extends SyncableModel> implements EntitySyncer {
  BaseEntitySyncer({
    required this.entity,
    required RemoteSyncAdapter<M> remote,
    required LocalSyncStore<M> local,
    Future<M> Function(M model, FkResolver resolver)? resolveFks,
  }) : _remote = remote,
       _local = local,
       _resolveFks = resolveFks;

  final RemoteSyncAdapter<M> _remote;
  final LocalSyncStore<M> _local;
  final Future<M> Function(M model, FkResolver resolver)? _resolveFks;

  @override
  final String entity;

  // BaseEntitySyncer entities are cursor-bearing: `pull` returns the max
  // `updatedAt` it observed, which the engine persists as this entity's
  // delta-sync cursor.
  @override
  bool get hasCursor => true;

  @override
  Future<void> push(OutboxRow entry, FkResolver resolver) async {
    if (entry.op == 'create') {
      await _pushCreate(entry.clientUuid, resolver);
    } else if (entry.op == 'update') {
      await _pushUpdate(entry.clientUuid, resolver);
    } else if (entry.op == 'delete') {
      await _pushDelete(entry.clientUuid);
    }
    // Any other op is outside the {'create','update','delete'} contract
    // (see `OutboxRow.op`) — nothing to do defensively.
  }

  Future<void> _pushCreate(String clientUuid, FkResolver resolver) async {
    final model = await _local.getByClientUuid(clientUuid);
    if (model == null) {
      // Row is gone (e.g. created-then-deleted offline, annihilated out of
      // the outbox already) — nothing left to push.
      return;
    }

    final toSend = _resolveFks == null
        ? model
        : await _resolveFks(model, resolver);
    final created = await _remote.add(toSend);
    // Reconcile: P1's create is idempotent on client_uuid, so a retried
    // push (this entry re-run after an ack was lost) returns the SAME
    // server row — writing it back here is a no-op the second time round,
    // never a duplicate (setServerId is an UPDATE keyed by clientUuid).
    resolver.record(entity, clientUuid, created.syncServerId);
    await _local.setServerId(
      clientUuid,
      created.syncServerId,
      created.syncUpdatedAt,
    );
  }

  Future<void> _pushUpdate(String clientUuid, FkResolver resolver) async {
    final model = await _local.getByClientUuid(clientUuid);
    if (model == null) return;

    final toSend = _resolveFks == null
        ? model
        : await _resolveFks(model, resolver);

    if (model.syncServerId.isEmpty) {
      // Defensive: a standalone `update` entry should only ever exist for
      // an already-synced row — outbox coalescing collapses a same-row
      // create+update into a single `create`. If the server id is somehow
      // still missing, fall back to creating it rather than PUTting an
      // empty id.
      final created = await _remote.add(toSend);
      resolver.record(entity, clientUuid, created.syncServerId);
      await _local.setServerId(
        clientUuid,
        created.syncServerId,
        created.syncUpdatedAt,
      );
      return;
    }

    final updated = await _remote.update(toSend);
    await _local.setServerId(
      clientUuid,
      updated.syncServerId,
      updated.syncUpdatedAt,
    );
  }

  Future<void> _pushDelete(String clientUuid) async {
    final model = await _local.getByClientUuid(clientUuid);
    final serverId = model?.syncServerId ?? '';

    if (serverId.isNotEmpty) {
      await _remote.delete(serverId);
    }
    // Else: never synced (no server id) — nothing to delete server-side;
    // this shouldn't normally happen since create+delete annihilate in the
    // outbox, but is handled defensively.

    await _local.hardDelete(clientUuid);
  }

  /// A belt-and-suspenders backstop on the drain loop below: no realistic
  /// pull should ever take this many round trips (500 rows/page means this
  /// bounds a single [pull] to ~5,000,000 rows), so hitting it means the
  /// no-forward-progress check has a bug — stop rather than loop forever.
  static const int _maxPullIterations = 10000;

  /// The cursor a first-ever pull starts from: old enough that every real
  /// row is strictly after it, so [getSince] always receives a non-null
  /// instant (see below).
  static final DateTime _epoch = DateTime.utc(1970);

  @override
  Future<DateTime?> pull(DateTime? since) async {
    // The backend's list endpoints serve TWO different orders depending on
    // whether `updated_since` is present: the display path (`id DESC`, used
    // when the query param is absent — i.e. when [getSince] is called with
    // `null`) and the sync/drain path (`updated_at ASC, id ASC`, capped at
    // 500 rows, used whenever `updated_since` IS present). Only the drain
    // path can be walked forward to completion by re-querying with the last
    // page's max `updatedAt`. So [since] is never forwarded to [getSince]
    // as-is: a first-ever sync (`since == null`) is substituted with an
    // epoch instant instead, guaranteeing `updated_since` is ALWAYS sent and
    // the drain path is ALWAYS the one hit — including on the very first
    // pull.
    //
    // From there, loop: fetch a page, apply every row, and re-query from the
    // page's max `updatedAt` — walking forward through however many
    // 500-row pages the backend needs to hand back every changed row.
    // Terminates when a page is empty OR its max `updatedAt` doesn't
    // advance past the cursor just queried with (i.e. every remaining row
    // shares the boundary instant — re-querying it would just return the
    // same page forever). The `>=` boundary overlap this implies (the
    // boundary row(s) get applied again next page) is harmless: applying a
    // pulled row is idempotent — see [_applyPulledRow].
    var cursor = since ?? _epoch;
    DateTime? overallMax;

    for (var i = 0; i < _maxPullIterations; i++) {
      final rows = await _remote.getSince(cursor);

      DateTime? pageMax;
      for (final server in rows) {
        await _applyPulledRow(server);
        if (pageMax == null || server.syncUpdatedAt.isAfter(pageMax)) {
          pageMax = server.syncUpdatedAt;
        }
      }

      if (pageMax != null &&
          (overallMax == null || pageMax.isAfter(overallMax))) {
        overallMax = pageMax;
      }

      if (pageMax == null || !pageMax.isAfter(cursor)) {
        // Empty page, or no forward progress possible — stop.
        break;
      }
      cursor = pageMax;
    }

    // No row was ever observed across any page: nothing changed, so return
    // the ORIGINAL [since] (which may itself be null) rather than the
    // internal epoch substitution — the engine keeps whatever cursor it
    // already had (or, on a genuinely-empty first sync, keeps advancing its
    // own null-cursor fallback; see `SyncEngine._pullPhase`).
    return overallMax ?? since;
  }

  /// Applies one server row to the local mirror, honouring delete-wins and
  /// last-writer-wins over any conflicting local mutation.
  Future<void> _applyPulledRow(M server) async {
    final local = await _findLocal(server);

    // The row is keyed locally by `clientUuid` (the drift primary key).
    // Normally that's `server.clientUuid` (P1 echoes it back); but when the
    // server omitted it and we only found the row via [_findLocal]'s
    // server-id fallback, the row must still be written back under the
    // LOCAL row's clientUuid — never under the server's blank one, which
    // would insert a stray second row instead of updating the real one.
    final clientUuid = server.syncClientUuid.isNotEmpty
        ? server.syncClientUuid
        : (local?.syncClientUuid ?? '');
    if (clientUuid.isEmpty) {
      // No way to key this row locally (shouldn't happen — P1 always
      // echoes client_uuid on rows the client has ever seen) — skip rather
      // than risk corrupting the mirror with an empty-keyed row.
      return;
    }

    if (local == null) {
      await _local.upsert(_withClientUuid(server, clientUuid), pending: false);
      return;
    }

    if (local.syncDeletedLocally && local.syncPending) {
      // Delete-wins / don't-resurrect: the local delete hasn't pushed yet
      // (or is about to) and will win server-side too — never let an
      // inbound row bring a locally-deleted row back.
      return;
    }

    if (local.syncPending && !local.syncDeletedLocally) {
      // Pending local EDIT: last-writer-wins by `updatedAt`, instant-based
      // (never `==` — drift returns local-zone DateTimes on read).
      if (server.syncUpdatedAt.isAfter(local.syncUpdatedAt)) {
        await _local.upsert(
          _withClientUuid(server, clientUuid),
          pending: false,
        );
      }
      // Else: local is newer or equal — keep the local edit, skip.
      return;
    }

    // Clean (not pending) local row — accept the server's version outright.
    await _local.upsert(_withClientUuid(server, clientUuid), pending: false);
  }

  /// Looks up the local row a pulled [server] row corresponds to: primarily
  /// by `client_uuid` (which P1 echoes back); if the server didn't send one,
  /// falls back to matching by server id.
  Future<M?> _findLocal(M server) async {
    if (server.syncClientUuid.isNotEmpty) {
      return _local.getByClientUuid(server.syncClientUuid);
    }
    if (server.syncServerId.isNotEmpty) {
      return _local.getByServerId(server.syncServerId);
    }
    return null;
  }

  /// Returns [server] as-is if it already carries [clientUuid], else a copy
  /// with it substituted — every other field untouched.
  M _withClientUuid(M server, String clientUuid) {
    return server.withSyncClientUuid(clientUuid) as M;
  }
}
