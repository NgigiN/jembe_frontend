import 'dart:async';

import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/outbox_coalescing.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';

/// The flag-on local-first plumbing shared by every offline-mirrored entity
/// repository (`land`, and the ones that follow it).
///
/// Each concrete repository (e.g. `LandRepositoryImpl`) still owns its own
/// per-entity model construction — the create factory, the update copy that
/// preserves `serverId`, and the model↔domain mapping — because that shape
/// differs per entity. What's identical across every entity is the
/// write-plumbing around that model once it exists: stage it locally, queue
/// it on the outbox, and kick a background sync pass; or, for a delete, mark
/// the row a tombstone and queue the delete intent. This mixin extracts
/// exactly that invariant plumbing so each entity's repository only has to
/// mix it in and supply three getters.
mixin OfflineRepositoryMixin {
  /// The outbox `entity` tag for this repository's rows (e.g. 'land').
  String get syncEntity;
  OutboxDao? get syncOutbox;
  SyncEngine? get syncEngine;

  /// Flag-on CREATE/UPDATE plumbing: local upsert(pending:true) → outbox
  /// enqueue(op, payload) → fire-and-forget syncNow. Caller has already built
  /// [model] and its [payload] json and chosen [op] (create or update).
  Future<void> stageWrite<M extends SyncableModel>(
    LocalSyncStore<M> local,
    M model,
    String payload,
    OutboxOp op,
  ) async {
    await local.upsert(model, pending: true);
    await syncOutbox!.enqueue(OutboxIntent(
      op: op, entity: syncEntity,
      clientUuid: model.syncClientUuid, payload: payload,
    ));
    unawaited(syncEngine!.syncNow());
  }

  /// Flag-on DELETE plumbing: mark the local row a tombstone → enqueue a
  /// delete intent (no payload) → fire-and-forget syncNow.
  Future<void> stageDelete<M extends SyncableModel>(
    LocalSyncStore<M> local,
    String clientUuid,
  ) async {
    await local.markDeleted(clientUuid);
    await syncOutbox!.enqueue(
      OutboxIntent(op: OutboxOp.delete, entity: syncEntity, clientUuid: clientUuid),
    );
    unawaited(syncEngine!.syncNow());
  }

  /// Flag-on reactive read: map a local model stream to domain entities.
  Stream<List<E>> watchAsDomain<M, E>(
    Stream<List<M>> source, E Function(M) toDomain,
  ) => source.map((models) => models.map(toDomain).toList());
}
