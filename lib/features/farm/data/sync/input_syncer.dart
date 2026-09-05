import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';

/// Thin [RemoteSyncAdapter] over [InputRemoteDataSource], mapping the
/// generic add/update/delete/getSince onto the input endpoints. Exceptions
/// (`NetworkException`/`ServerException`) propagate straight through — the
/// datasource throws them and neither this adapter nor [BaseEntitySyncer]
/// catches them.
class InputRemoteAdapter implements RemoteSyncAdapter<InputModel> {
  InputRemoteAdapter(this._remote);

  final InputRemoteDataSource _remote;

  @override
  Future<InputModel> add(InputModel model) => _remote.addInput(model);

  @override
  Future<InputModel> update(InputModel model) => _remote.updateInput(model);

  @override
  Future<void> delete(String serverId) => _remote.deleteInput(serverId);

  @override
  Future<List<InputModel>> getSince(DateTime? since) =>
      // The sync pull is unfiltered (all rows since the cursor) — the
      // `sourceType` app-level filter is a LOCAL read concern only (see
      // `InputLocalDataSource.watchInputs`), never a sync-pull concern.
      _remote.getInputs(updatedSince: since);
}

/// Concrete [EntitySyncer] for the `input` entity.
///
/// The push dispatch (create/update/delete + server-id reconcile) and the
/// pull + delete-wins/last-writer-wins reconciler live once, generically, in
/// [BaseEntitySyncer]; this class only wires input's remote datasource (via
/// [InputRemoteAdapter]) and local mirror ([InputLocalDataSource], which
/// implements `LocalSyncStore<InputModel>`) into it and stamps the
/// `'input'` entity tag.
class InputSyncer extends BaseEntitySyncer<InputModel> {
  InputSyncer({
    required InputRemoteDataSource remote,
    required InputLocalDataSource local,
  }) : super(entity: 'input', remote: InputRemoteAdapter(remote), local: local);
}
