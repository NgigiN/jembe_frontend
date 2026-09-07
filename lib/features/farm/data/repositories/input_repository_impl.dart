import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/offline/offline_repository.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/outbox_coalescing.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [InputRepository].
///
/// ## Flag off (today's behavior, with one intentional bug fix)
/// Every method talks straight to [remoteDataSource], mapping
/// `NetworkException`/`ServerException` to [NetworkFailure]/[ServerFailure].
/// This is rule zero for the offline rollout: with
/// `OfflineConfig.enabled == false`, this class behaves exactly as it did
/// before the offline pipeline existed — with one deliberate exception:
/// `notes` is now sent on the wire (see [_toModel]'s doc comment), fixing a
/// pre-existing drop; the backend has always accepted it.
///
/// ## Flag on — local-first + outbox
/// Reads come from [local] (the drift-backed mirror); writes land on
/// [local] first, get queued on [outbox] for the syncer to push, and kick
/// off a background [sync] pass — all before this method returns, so the
/// caller never blocks on the network.
///
/// ### Presentation identity
/// When the flag is on, every domain [Input] this repository hands out has
/// **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updateInput] and [deleteInput] therefore treat the incoming
/// `id`/`input.id` as a `clientUuid`, never a server id. The drift row's
/// nullable `serverId` is used ONLY by the syncer (via
/// `InputModel.fromDrift`) to build server URLs — it never surfaces
/// through this repository's presentation.
class InputRepositoryImpl
    with OfflineRepositoryMixin
    implements InputRepository {
  InputRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });

  final InputRemoteDataSource remoteDataSource;
  final InputLocalDataSource? local;
  final OutboxDao? outbox;
  final SyncEngine? sync;
  final UuidGen uuid;

  /// True only when the flag is on AND every offline collaborator this
  /// repository needs for the local-first path was actually supplied.
  /// Falling back to the flag-off (remote) path if any is missing keeps a
  /// half-wired repository safe rather than crashing on a null dependency.
  bool get _offlineFirst =>
      OfflineConfig.enabled && local != null && outbox != null && sync != null;

  @override
  String get syncEntity => 'input';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  // NOTE: this now DOES pass `notes:` on the flag-off `addInput`/`updateInput`
  // path. Pre-P3 (see `git show 4ec8dd7:.../input_repository_impl.dart`), the
  // wire model never set `notes`, so it was silently dropped regardless of
  // what the caller's `Input.notes` held — a pre-existing bug, not a
  // deliberate contract. The backend has always fully supported it
  // (`internal/models/plants/input.go`'s `Notes` column, `input_service.go`'s
  // select, and the InputRequest DTO/mapper all already bind it), so there is
  // no reason to keep suppressing it here. `_toModel` is used ONLY by the
  // flag-off remote path (below); the flag-ON local-first path builds its own
  // model via `InputModel.create`, which has always carried `notes:` into the
  // local mirror.
  InputModel _toModel(Input input) {
    return InputModel(
      id: input.id,
      sourceType: input.sourceType,
      sourceId: input.sourceId,
      animalId: input.animalId,
      type: input.type,
      quantity: input.quantity,
      cost: input.cost,
      date: input.date,
      notes: input.notes,
      createdAt: input.createdAt,
      updatedAt: input.updatedAt,
    );
  }

  Input _toInput(InputModel model) => Input(
    id: model.clientUuid,
    sourceType: model.sourceType,
    sourceId: model.sourceId,
    animalId: model.animalId,
    type: model.type,
    quantity: model.quantity,
    cost: model.cost,
    date: model.date,
    notes: model.notes,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  @override
  Stream<List<Input>> watchInputs({String? sourceType}) {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(
        local!.watchInputs(sourceType: sourceType),
        _toInput,
      );
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetInputsEvent` path) — this only needs to compile
    // and never crash. A single-emission stream mirroring `getInputs()`
    // does that without adding a second remote-fetch code path.
    return Stream.fromFuture(
      getInputs(
        sourceType: sourceType,
      ).then((result) => result.fold((_) => <Input>[], (inputs) => inputs)),
    );
  }

  @override
  Future<Either<Failure, List<Input>>> getInputs({String? sourceType}) async {
    if (_offlineFirst) {
      final models = await local!.watchInputs(sourceType: sourceType).first;
      return Right(models.map(_toInput).toList());
    }
    try {
      final inputs = await remoteDataSource.getInputs(sourceType: sourceType);
      return Right(inputs);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Input>> addInput(Input input) async {
    if (_offlineFirst) {
      final model = InputModel.create(
        sourceType: input.sourceType,
        sourceId: input.sourceId,
        animalId: input.animalId,
        type: input.type,
        quantity: input.quantity,
        cost: input.cost,
        date: input.date,
        notes: input.notes,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return Right(_toInput(model));
    }

    try {
      final result = await remoteDataSource.addInput(_toModel(input));
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Input>> updateInput(Input input) async {
    if (_offlineFirst) {
      // `input.id` is a clientUuid (presentation identity) — see class
      // docs.
      final existing = await local!.getByClientUuid(input.id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = InputModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: input.id,
        sourceType: input.sourceType,
        sourceId: input.sourceId,
        animalId: input.animalId,
        type: input.type,
        quantity: input.quantity,
        cost: input.cost,
        date: input.date,
        notes: input.notes,
        createdAt: input.createdAt,
        updatedAt: DateTime.now(),
        pending: true,
      );
      await stageWrite(
        local!,
        updated,
        jsonEncode(updated.toJson()),
        OutboxOp.update,
      );
      return Right(input);
    }

    try {
      final result = await remoteDataSource.updateInput(_toModel(input));
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInput(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    try {
      await remoteDataSource.deleteInput(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
