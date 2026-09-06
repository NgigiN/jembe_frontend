import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';

/// Thin [RemoteSyncAdapter] over [SeasonRemoteDataSource], mapping the
/// generic add/update/delete/getSince onto the season endpoints. Exceptions
/// (`NetworkException`/`ServerException`) propagate straight through — the
/// datasource throws them and neither this adapter nor [BaseEntitySyncer]
/// catches them.
class SeasonRemoteAdapter implements RemoteSyncAdapter<SeasonModel> {
  SeasonRemoteAdapter(this._remote);

  final SeasonRemoteDataSource _remote;

  @override
  Future<SeasonModel> add(SeasonModel model) => _remote.addSeason(model);

  @override
  Future<SeasonModel> update(SeasonModel model) => _remote.updateSeason(model);

  @override
  Future<void> delete(String serverId) => _remote.deleteSeason(serverId);

  @override
  Future<List<SeasonModel>> getSince(DateTime? since) =>
      _remote.getSeasons(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `season` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically, in
/// [BaseEntitySyncer]; this class only wires season's remote datasource (via
/// [SeasonRemoteAdapter]) and local mirror ([SeasonLocalDataSource], which
/// implements `LocalSyncStore<SeasonModel>`) into it and stamps the
/// `'season'` entity tag.
///
/// See `season_model.dart`'s `// TODO(P4)` note: `plantId`/`landId` FK
/// reconciliation for an unsynced parent is out of scope for P3 — this
/// syncer only ever pushes/pulls seasons whose parent plant/land is already
/// synced.
class SeasonSyncer extends BaseEntitySyncer<SeasonModel> {
  SeasonSyncer({
    required SeasonRemoteDataSource remote,
    required SeasonLocalDataSource local,
  }) : super(
         entity: 'season',
         remote: SeasonRemoteAdapter(remote),
         local: local,
       );
}
