import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';

/// Thin [RemoteSyncAdapter] over [PlantRemoteDataSource], mapping the generic
/// add/update/delete/getSince onto the plant endpoints. Exceptions
/// (`NetworkException`/`ServerException`) propagate straight through — the
/// datasource throws them and neither this adapter nor [BaseEntitySyncer]
/// catches them.
class PlantRemoteAdapter implements RemoteSyncAdapter<PlantModel> {
  PlantRemoteAdapter(this._remote);

  final PlantRemoteDataSource _remote;

  @override
  Future<PlantModel> add(PlantModel model) => _remote.addPlant(model);

  @override
  Future<PlantModel> update(PlantModel model) => _remote.updatePlant(model);

  @override
  Future<void> delete(String serverId) => _remote.deletePlant(serverId);

  @override
  Future<List<PlantModel>> getSince(DateTime? since) =>
      _remote.getPlants(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `plant` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically, in
/// [BaseEntitySyncer]; this class only wires plant's remote datasource (via
/// [PlantRemoteAdapter]) and local mirror ([PlantLocalDataSource], which
/// implements `LocalSyncStore<PlantModel>`) into it and stamps the
/// `'plant'` entity tag.
class PlantSyncer extends BaseEntitySyncer<PlantModel> {
  PlantSyncer({
    required PlantRemoteDataSource remote,
    required PlantLocalDataSource local,
  }) : super(
         entity: 'plant',
         remote: PlantRemoteAdapter(remote),
         local: local,
       );
}
