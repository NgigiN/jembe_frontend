import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';

/// Thin [RemoteSyncAdapter] over [LandRemoteDataSource], mapping the generic
/// add/update/delete/getSince onto the land endpoints. Exceptions
/// (`NetworkException`/`ServerException`) propagate straight through — the
/// datasource throws them and neither this adapter nor [BaseEntitySyncer]
/// catches them.
class LandRemoteAdapter implements RemoteSyncAdapter<LandModel> {
  LandRemoteAdapter(this._remote);

  final LandRemoteDataSource _remote;

  @override
  Future<LandModel> add(LandModel model) => _remote.addLand(model);

  @override
  Future<LandModel> update(LandModel model) => _remote.updateLand(model);

  @override
  Future<void> delete(String serverId) => _remote.deleteLand(serverId);

  @override
  Future<List<LandModel>> getSince(DateTime? since) =>
      _remote.getLands(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `land` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler now live once, generically,
/// in [BaseEntitySyncer]; this class only wires land's remote datasource
/// (via [LandRemoteAdapter]) and local mirror ([LandLocalDataSource], which
/// implements `LocalSyncStore<LandModel>`) into it and stamps the `'land'`
/// entity tag. Behavior is identical to the original hand-written syncer —
/// see `land_syncer_test.dart` and the P2 e2e goldens.
class LandSyncer extends BaseEntitySyncer<LandModel> {
  LandSyncer({
    required LandRemoteDataSource remote,
    required LandLocalDataSource local,
  }) : super(
         entity: 'land',
         remote: LandRemoteAdapter(remote),
         local: local,
       );
}
