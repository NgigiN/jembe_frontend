import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';

/// Thin [RemoteSyncAdapter] over [ActivityRemoteDataSource], mapping the
/// generic add/update/delete/getSince onto the activity endpoints.
/// Exceptions (`NetworkException`/`ServerException`) propagate straight
/// through — the datasource throws them and neither this adapter nor
/// [BaseEntitySyncer] catches them.
class ActivityRemoteAdapter implements RemoteSyncAdapter<ActivityModel> {
  ActivityRemoteAdapter(this._remote);

  final ActivityRemoteDataSource _remote;

  @override
  Future<ActivityModel> add(ActivityModel model) =>
      _remote.addActivity(model);

  @override
  Future<ActivityModel> update(ActivityModel model) =>
      _remote.updateActivity(model);

  @override
  Future<void> delete(String serverId) => _remote.deleteActivity(serverId);

  @override
  Future<List<ActivityModel>> getSince(DateTime? since) =>
      // The sync pull is unfiltered (all rows since the cursor) — the
      // `sourceType` app-level filter is a LOCAL read concern only (see
      // `ActivityLocalDataSource.watchActivities`), never a sync-pull
      // concern.
      _remote.getActivities(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `activity` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically, in
/// [BaseEntitySyncer]; this class only wires activity's remote datasource
/// (via [ActivityRemoteAdapter]) and local mirror ([ActivityLocalDataSource],
/// which implements `LocalSyncStore<ActivityModel>`) into it and stamps the
/// `'activity'` entity tag.
class ActivitySyncer extends BaseEntitySyncer<ActivityModel> {
  ActivitySyncer({
    required ActivityRemoteDataSource remote,
    required ActivityLocalDataSource local,
  }) : super(
         entity: 'activity',
         remote: ActivityRemoteAdapter(remote),
         local: local,
       );
}
