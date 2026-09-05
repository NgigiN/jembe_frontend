/// Contracts a data model + its remote/local data sources must satisfy to be
/// driven by `BaseEntitySyncer`.
///
/// These three abstractions are the seam that lets the subtle LWW /
/// delete-wins / id-reconciliation logic — proven by the `land` pilot's unit
/// tests and the P2 end-to-end goldens — live in ONE generic place
/// (`BaseEntitySyncer`) instead of being copy-pasted per entity:
///
/// - [SyncableModel] — the read-only sync fields the base syncer needs off any
///   model (client uuid, server id, updatedAt, pending, deletedLocally), plus
///   a copy-with-client-uuid used by the pull reconciler.
/// - [RemoteSyncAdapter] — the four network operations (add/update/delete/
///   getSince) a per-entity remote data source exposes.
/// - [LocalSyncStore] — the local-mirror writes/reads the base syncer performs.
///
/// See `base_entity_syncer.dart` for how they are wired together.
library;

/// The sync-state fields `BaseEntitySyncer` reads off a data model.
///
/// Getters are `sync`-prefixed to avoid clashing with any field a concrete
/// model already exposes under a plainer name (e.g. `LandModel.id`, whose
/// meaning — the *server* id — must not be confused with the local client
/// uuid). A model maps these to its own fields.
abstract class SyncableModel {
  /// The local-only identity (drift primary key) that tracks this row before
  /// and independently of the server-assigned id.
  String get syncClientUuid;

  /// The server-assigned id, or `''` while the row has never synced.
  String get syncServerId;

  /// The instant this row was last written, used for last-writer-wins on pull.
  DateTime get syncUpdatedAt;

  /// True while this row carries a local mutation not yet acked by the server.
  bool get syncPending;

  /// True while this row is a local tombstone awaiting delete-sync.
  bool get syncDeletedLocally;

  /// Returns this model with [clientUuid] substituted as its [syncClientUuid],
  /// every other field untouched — or `this` unchanged when it already carries
  /// [clientUuid].
  ///
  /// Used by the pull reconciler to re-key a server row (which may arrive with
  /// a blank client_uuid) under the local row's client uuid before upserting,
  /// so it updates the real row instead of inserting a stray one. The concrete
  /// override returns its own type (e.g. `LandModel`); `BaseEntitySyncer` casts
  /// the result back to its type parameter.
  SyncableModel withSyncClientUuid(String clientUuid);
}

/// The four network operations `BaseEntitySyncer` drives for a single entity.
///
/// Implementations wrap a per-entity remote data source and MUST let
/// `NetworkException`/`ServerException` propagate (never catch-and-swallow) —
/// the sync engine's push/pull error matrix depends on it.
abstract class RemoteSyncAdapter<M> {
  /// Creates [model] server-side and returns the stored row (with its
  /// server id + server `updatedAt`). Idempotent on client uuid: a retried
  /// create returns the already-created row rather than duplicating it.
  Future<M> add(M model);

  /// Updates the already-synced [model] server-side and returns the stored row.
  Future<M> update(M model);

  /// Deletes the row identified by [serverId] server-side.
  Future<void> delete(String serverId);

  /// Fetches rows changed strictly after [since] (or every row when null).
  Future<List<M>> getSince(DateTime? since);
}

/// The local-mirror reads/writes `BaseEntitySyncer` performs for a single
/// entity. Every method keys rows by client uuid (the mirror's primary key).
abstract class LocalSyncStore<M> {
  /// The row with the given [clientUuid], or `null`. Includes tombstones.
  Future<M?> getByClientUuid(String clientUuid);

  /// The row with the given server [serverId], or `null`.
  Future<M?> getByServerId(String serverId);

  /// Inserts [model], or replaces the row sharing its client uuid, writing the
  /// given [pending] flag onto the row.
  Future<void> upsert(M model, {required bool pending});

  /// Physically removes the row for [clientUuid] (after a delete has synced).
  Future<void> hardDelete(String clientUuid);

  /// Reconciles the row for [clientUuid] after a create/update syncs: sets
  /// [serverId] and [updatedAt], and clears `pending`.
  Future<void> setServerId(String clientUuid, String serverId, DateTime updatedAt);
}
