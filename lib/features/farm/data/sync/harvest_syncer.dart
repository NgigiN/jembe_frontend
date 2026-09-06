import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/data/sync/fk_translators.dart';

/// Thin [RemoteSyncAdapter] over [HarvestRemoteDataSource], mapping the
/// generic add/update/delete/getSince onto the harvest endpoints. Exceptions
/// (`NetworkException`/`ServerException`) propagate straight through — the
/// datasource throws them and neither this adapter nor [BaseEntitySyncer]
/// catches them.
class HarvestRemoteAdapter implements RemoteSyncAdapter<HarvestModel> {
  HarvestRemoteAdapter(this._remote);

  final HarvestRemoteDataSource _remote;

  @override
  Future<HarvestModel> add(HarvestModel model) => _remote.addHarvest(model);

  @override
  Future<HarvestModel> update(HarvestModel model) =>
      _remote.updateHarvest(model);

  @override
  Future<void> delete(String serverId) => _remote.deleteHarvest(serverId);

  @override
  Future<List<HarvestModel>> getSince(DateTime? since) =>
      // The sync pull is unfiltered (all rows since the cursor) — the
      // `seasonId` app-level filter is a LOCAL read concern only (see
      // `HarvestLocalDataSource.watchHarvests`), never a sync-pull concern.
      _remote.getHarvests(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `harvest` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically, in
/// [BaseEntitySyncer]; this class only wires harvest's remote datasource (via
/// [HarvestRemoteAdapter]) and local mirror ([HarvestLocalDataSource], which
/// implements `LocalSyncStore<HarvestModel>`) into it and stamps the
/// `'harvest'` entity tag.
///
/// FK reconciliation for `seasonId`/`revenueId` (an unsynced parent's
/// client_uuid substituted with its server id before push) is implemented
/// via [translateHarvestFks] — see `fk_translators.dart`.
class HarvestSyncer extends BaseEntitySyncer<HarvestModel> {
  HarvestSyncer({
    required HarvestRemoteDataSource remote,
    required HarvestLocalDataSource local,
  }) : super(
         entity: 'harvest',
         remote: HarvestRemoteAdapter(remote),
         local: local,
         resolveFks: translateHarvestFks,
       );
}
