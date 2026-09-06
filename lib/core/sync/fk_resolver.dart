import 'package:farm_tracker/core/sync/sync_contracts.dart';

/// Resolves a child record's foreign key — stored as the parent's
/// `client_uuid` while the parent is unsynced — to the parent's server `id`.
///
/// One instance lives for exactly one `SyncEngine` push phase. As parent
/// creates succeed during the phase, [record] captures their new server id in
/// an in-memory map; [resolve] checks that map first, then falls back to the
/// local mirror (for a parent that synced in an earlier pass). A `null` result
/// means "parent has no server id yet" — the caller parks the child.
class FkResolver {
  FkResolver(this._stores);

  /// Entity tag → its local mirror, for the prior-pass fallback. The same map
  /// the `DeletionsDataSource` uses; injected by `SyncEngine`.
  final Map<String, LocalSyncStore<SyncableModel>> _stores;

  final Map<String, Map<String, String>> _passMap = {};

  /// Captures that a just-pushed create of [entity]/[clientUuid] returned
  /// [serverId], so a later child in the same phase resolves without a DB read.
  void record(String entity, String clientUuid, String serverId) {
    if (clientUuid.isEmpty || serverId.isEmpty) return;
    (_passMap[entity] ??= {})[clientUuid] = serverId;
  }

  /// The server id for [entity]/[clientUuid], or null if the parent has not
  /// synced yet. In-pass records win; otherwise the local mirror is consulted.
  Future<String?> resolve(String entity, String clientUuid) async {
    final inPass = _passMap[entity]?[clientUuid];
    if (inPass != null) return inPass;

    final store = _stores[entity];
    if (store == null) return null;
    final parent = await store.getByClientUuid(clientUuid);
    final serverId = parent?.syncServerId ?? '';
    return serverId.isEmpty ? null : serverId;
  }
}
