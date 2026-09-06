import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/infrastructure_model.dart';

/// Thin [RemoteSyncAdapter] over [InfrastructureRemoteDataSource], mapping
/// the generic add/update/delete/getSince onto the infrastructure
/// endpoints. Exceptions (`NetworkException`/`ServerException`) propagate
/// straight through — the datasource throws them and neither this adapter
/// nor [BaseEntitySyncer] catches them.
class InfrastructureRemoteAdapter
    implements RemoteSyncAdapter<InfrastructureModel> {
  InfrastructureRemoteAdapter(this._remote);

  final InfrastructureRemoteDataSource _remote;

  @override
  Future<InfrastructureModel> add(InfrastructureModel model) =>
      _remote.addInfrastructure(model);

  @override
  Future<InfrastructureModel> update(InfrastructureModel model) =>
      _remote.updateInfrastructure(model);

  @override
  Future<void> delete(String serverId) =>
      _remote.deleteInfrastructure(serverId);

  @override
  Future<List<InfrastructureModel>> getSince(DateTime? since) =>
      _remote.getInfrastructures(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `infrastructure` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically,
/// in [BaseEntitySyncer]; this class only wires infrastructure's remote
/// datasource (via [InfrastructureRemoteAdapter]) and local mirror
/// ([InfrastructureLocalDataSource], which implements
/// `LocalSyncStore<InfrastructureModel>`) into it and stamps the
/// `'infrastructure'` entity tag.
class InfrastructureSyncer extends BaseEntitySyncer<InfrastructureModel> {
  InfrastructureSyncer({
    required InfrastructureRemoteDataSource remote,
    required InfrastructureLocalDataSource local,
  }) : super(
         entity: 'infrastructure',
         remote: InfrastructureRemoteAdapter(remote),
         local: local,
       );
}
