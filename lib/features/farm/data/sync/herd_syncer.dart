import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';

/// Thin [RemoteSyncAdapter] over [HerdRemoteDataSource], mapping the generic
/// add/update/delete/getSince onto the herd endpoints. Exceptions
/// (`NetworkException`/`ServerException`) propagate straight through — the
/// datasource throws them and neither this adapter nor [BaseEntitySyncer]
/// catches them.
class HerdRemoteAdapter implements RemoteSyncAdapter<HerdModel> {
  HerdRemoteAdapter(this._remote);

  final HerdRemoteDataSource _remote;

  @override
  Future<HerdModel> add(HerdModel model) => _remote.addHerd(model);

  @override
  Future<HerdModel> update(HerdModel model) => _remote.updateHerd(model);

  @override
  Future<void> delete(String serverId) => _remote.deleteHerd(serverId);

  @override
  Future<List<HerdModel>> getSince(DateTime? since) =>
      _remote.getHerds(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `herd` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically,
/// in [BaseEntitySyncer]; this class only wires herd's remote datasource
/// (via [HerdRemoteAdapter]) and local mirror ([HerdLocalDataSource], which
/// implements `LocalSyncStore<HerdModel>`) into it and stamps the `'herd'`
/// entity tag.
class HerdSyncer extends BaseEntitySyncer<HerdModel> {
  HerdSyncer({
    required HerdRemoteDataSource remote,
    required HerdLocalDataSource local,
  }) : super(entity: 'herd', remote: HerdRemoteAdapter(remote), local: local);
}
