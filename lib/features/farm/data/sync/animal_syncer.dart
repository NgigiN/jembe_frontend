import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';

/// Thin [RemoteSyncAdapter] over [AnimalRemoteDataSource], mapping the generic
/// add/update/delete/getSince onto the animal endpoints. Exceptions
/// (`NetworkException`/`ServerException`) propagate straight through — the
/// datasource throws them and neither this adapter nor [BaseEntitySyncer]
/// catches them.
class AnimalRemoteAdapter implements RemoteSyncAdapter<AnimalModel> {
  AnimalRemoteAdapter(this._remote);

  final AnimalRemoteDataSource _remote;

  @override
  Future<AnimalModel> add(AnimalModel model) => _remote.addAnimal(model);

  @override
  Future<AnimalModel> update(AnimalModel model) => _remote.updateAnimal(model);

  @override
  Future<void> delete(String serverId) => _remote.deleteAnimal(serverId);

  @override
  Future<List<AnimalModel>> getSince(DateTime? since) =>
      _remote.getAnimals(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `animal` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically, in
/// [BaseEntitySyncer]; this class only wires animal's remote datasource (via
/// [AnimalRemoteAdapter]) and local mirror ([AnimalLocalDataSource], which
/// implements `LocalSyncStore<AnimalModel>`) into it and stamps the
/// `'animal'` entity tag.
class AnimalSyncer extends BaseEntitySyncer<AnimalModel> {
  AnimalSyncer({
    required AnimalRemoteDataSource remote,
    required AnimalLocalDataSource local,
  }) : super(
         entity: 'animal',
         remote: AnimalRemoteAdapter(remote),
         local: local,
       );
}
