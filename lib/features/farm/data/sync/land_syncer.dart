import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';

/// Concrete [EntitySyncer] for the `land` entity.
///
/// Pushes queued outbox mutations to the P1 backend via
/// [LandRemoteDataSource] and pulls server deltas back into
/// [LandLocalDataSource]. Owns no retry/backoff/ordering logic — that's
/// `SyncEngine`'s job; this class only ever does ONE thing per call: apply
/// one outbox entry, or pull-and-reconcile one page of server changes.
///
/// `NetworkException`/`ServerException` thrown by the remote datasource are
/// deliberately left to propagate out of [push]/[pull] — the engine's
/// push/pull error matrix (see `entity_syncer.dart`) handles them. This
/// class never catches-and-swallows them.
class LandSyncer implements EntitySyncer {
  LandSyncer({required LandRemoteDataSource remote, required LandLocalDataSource local})
    : _remote = remote,
      _local = local;

  final LandRemoteDataSource _remote;
  final LandLocalDataSource _local;

  @override
  String get entity => 'land';

  @override
  Future<void> push(OutboxRow entry) async {
    if (entry.op == 'create') {
      await _pushCreate(entry.clientUuid);
    } else if (entry.op == 'update') {
      await _pushUpdate(entry.clientUuid);
    } else if (entry.op == 'delete') {
      await _pushDelete(entry.clientUuid);
    }
    // Any other op is outside the {'create','update','delete'} contract
    // (see `OutboxRow.op`) — nothing to do defensively.
  }

  Future<void> _pushCreate(String clientUuid) async {
    final model = await _local.getByClientUuid(clientUuid);
    if (model == null) {
      // Row is gone (e.g. created-then-deleted offline, annihilated out of
      // the outbox already) — nothing left to push.
      return;
    }

    final created = await _remote.addLand(model);
    // Reconcile: P1's create is idempotent on client_uuid, so a retried
    // push (this entry re-run after an ack was lost) returns the SAME
    // server row — writing it back here is a no-op the second time round,
    // never a duplicate (setServerId is an UPDATE keyed by clientUuid).
    await _local.setServerId(clientUuid, created.id, created.updatedAt);
  }

  Future<void> _pushUpdate(String clientUuid) async {
    final model = await _local.getByClientUuid(clientUuid);
    if (model == null) return;

    if (model.id.isEmpty) {
      // Defensive: a standalone `update` entry should only ever exist for
      // an already-synced row — outbox coalescing collapses a same-row
      // create+update into a single `create`. If the server id is somehow
      // still missing, fall back to creating it rather than PUTting an
      // empty id.
      final created = await _remote.addLand(model);
      await _local.setServerId(clientUuid, created.id, created.updatedAt);
      return;
    }

    final updated = await _remote.updateLand(model);
    await _local.setServerId(clientUuid, updated.id, updated.updatedAt);
  }

  Future<void> _pushDelete(String clientUuid) async {
    final model = await _local.getByClientUuid(clientUuid);
    final serverId = model?.id ?? '';

    if (serverId.isNotEmpty) {
      await _remote.deleteLand(serverId);
    }
    // Else: never synced (no server id) — nothing to delete server-side;
    // this shouldn't normally happen since create+delete annihilate in the
    // outbox, but is handled defensively.

    await _local.hardDelete(clientUuid);
  }

  @override
  Future<DateTime?> pull(DateTime? since) async {
    final rows = await _remote.getLands(updatedSince: since);

    DateTime? maxUpdatedAt;
    for (final server in rows) {
      await _applyPulledRow(server);
      if (maxUpdatedAt == null || server.updatedAt.isAfter(maxUpdatedAt)) {
        maxUpdatedAt = server.updatedAt;
      }
    }
    return maxUpdatedAt;
  }

  /// Applies one server row to the local mirror, honouring delete-wins and
  /// last-writer-wins over any conflicting local mutation.
  Future<void> _applyPulledRow(LandModel server) async {
    final local = await _findLocal(server);

    // The row is keyed locally by `clientUuid` (the drift primary key).
    // Normally that's `server.clientUuid` (P1 echoes it back); but when the
    // server omitted it and we only found the row via [_findLocal]'s
    // server-id fallback, the row must still be written back under the
    // LOCAL row's clientUuid — never under the server's blank one, which
    // would insert a stray second row instead of updating the real one.
    final clientUuid = server.clientUuid.isNotEmpty
        ? server.clientUuid
        : (local?.clientUuid ?? '');
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

    if (local.deletedLocally && local.pending) {
      // Delete-wins / don't-resurrect: the local delete hasn't pushed yet
      // (or is about to) and will win server-side too — never let an
      // inbound row bring a locally-deleted land back.
      return;
    }

    if (local.pending && !local.deletedLocally) {
      // Pending local EDIT: last-writer-wins by `updatedAt`, instant-based
      // (never `==` — drift returns local-zone DateTimes on read).
      if (server.updatedAt.isAfter(local.updatedAt)) {
        await _local.upsert(_withClientUuid(server, clientUuid), pending: false);
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
  Future<LandModel?> _findLocal(LandModel server) async {
    if (server.clientUuid.isNotEmpty) {
      return _local.getByClientUuid(server.clientUuid);
    }
    if (server.id.isNotEmpty) {
      return _local.getByServerId(server.id);
    }
    return null;
  }

  /// Returns [server] as-is if it already carries [clientUuid], else a copy
  /// with it substituted — every other field untouched.
  LandModel _withClientUuid(LandModel server, String clientUuid) {
    if (server.clientUuid == clientUuid) return server;
    return LandModel(
      id: server.id,
      clientUuid: clientUuid,
      userId: server.userId,
      name: server.name,
      size: server.size,
      location: server.location,
      soilType: server.soilType,
      tenureType: server.tenureType,
      createdAt: server.createdAt,
      updatedAt: server.updatedAt,
    );
  }
}
