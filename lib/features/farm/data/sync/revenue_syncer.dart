import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';

/// Thin [RemoteSyncAdapter] over [RevenueRemoteDataSource], mapping the
/// generic add/update/delete/getSince onto the revenue endpoints. Exceptions
/// (`NetworkException`/`ServerException`) propagate straight through — the
/// datasource throws them and neither this adapter nor [BaseEntitySyncer]
/// catches them.
///
/// [getSince] passes ONLY `updatedSince` — never `source`/`startDate`/
/// `endDate`, which exist solely for the app's filtered list reads (see
/// `RevenueRemoteDataSource.getRevenues`'s doc).
class RevenueRemoteAdapter implements RemoteSyncAdapter<RevenueModel> {
  RevenueRemoteAdapter(this._remote);

  final RevenueRemoteDataSource _remote;

  @override
  Future<RevenueModel> add(RevenueModel model) => _remote.addRevenue(model);

  @override
  Future<RevenueModel> update(RevenueModel model) =>
      _remote.updateRevenue(model);

  @override
  Future<void> delete(String serverId) => _remote.deleteRevenue(serverId);

  @override
  Future<List<RevenueModel>> getSince(DateTime? since) =>
      _remote.getRevenues(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `revenue` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically,
/// in [BaseEntitySyncer]; this class only wires revenue's remote datasource
/// (via [RevenueRemoteAdapter]) and local mirror ([RevenueLocalDataSource],
/// which implements `LocalSyncStore<RevenueModel>`) into it and stamps the
/// `'revenue'` entity tag.
class RevenueSyncer extends BaseEntitySyncer<RevenueModel> {
  RevenueSyncer({
    required RevenueRemoteDataSource remote,
    required RevenueLocalDataSource local,
  }) : super(
         entity: 'revenue',
         remote: RevenueRemoteAdapter(remote),
         local: local,
       );
}
