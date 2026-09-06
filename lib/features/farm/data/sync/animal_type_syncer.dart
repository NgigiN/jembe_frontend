import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';

/// Thin [RemoteSyncAdapter] over [AnimalTypeRemoteDataSource], mapping the
/// generic add/update/delete/getSince onto the animal-type endpoints.
/// Exceptions (`NetworkException`/`ServerException`) propagate straight
/// through — the datasource throws them and neither this adapter nor
/// [BaseEntitySyncer] catches them.
class AnimalTypeRemoteAdapter implements RemoteSyncAdapter<AnimalTypeModel> {
  AnimalTypeRemoteAdapter(this._remote);

  final AnimalTypeRemoteDataSource _remote;

  @override
  Future<AnimalTypeModel> add(AnimalTypeModel model) =>
      _remote.addAnimalType(model);

  @override
  Future<AnimalTypeModel> update(AnimalTypeModel model) =>
      _remote.updateAnimalType(model);

  @override
  Future<void> delete(String serverId) => _remote.deleteAnimalType(serverId);

  @override
  Future<List<AnimalTypeModel>> getSince(DateTime? since) =>
      _remote.getAnimalTypes(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `animal_type` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically,
/// in [BaseEntitySyncer]; this class only wires animal_type's remote
/// datasource (via [AnimalTypeRemoteAdapter]) and local mirror
/// ([AnimalTypeLocalDataSource], which implements
/// `LocalSyncStore<AnimalTypeModel>`) into it and stamps the
/// `'animal_type'` entity tag.
class AnimalTypeSyncer extends BaseEntitySyncer<AnimalTypeModel> {
  AnimalTypeSyncer({
    required AnimalTypeRemoteDataSource remote,
    required AnimalTypeLocalDataSource local,
  }) : super(
         entity: 'animal_type',
         remote: AnimalTypeRemoteAdapter(remote),
         local: local,
       );
}
