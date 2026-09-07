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
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/infrastructure_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [InfrastructureRepository].
///
/// ## Flag off (today's behavior — byte for byte)
/// Every method talks straight to [remoteDataSource], mapping
/// `NetworkException`/`ServerException` to [NetworkFailure]/[ServerFailure].
/// This is rule zero for the offline rollout: with
/// `OfflineConfig.enabled == false`, this class behaves exactly as it did
/// before the offline pipeline existed.
///
/// ## Flag on — local-first + outbox
/// Reads come from [local] (the drift-backed mirror); writes land on
/// [local] first, get queued on [outbox] for the syncer to push, and kick
/// off a background [sync] pass — all before this method returns, so the
/// caller never blocks on the network.
///
/// ### Presentation identity
/// When the flag is on, every domain [Infrastructure] this repository hands
/// out has **`id` == the local row's `clientUuid`** — the stable identity
/// that exists offline and never changes when the row later syncs and
/// gains a server id. [updateInfrastructure] and [deleteInfrastructure]
/// therefore treat the incoming `id` as a `clientUuid`, never a server id.
/// The drift row's nullable `serverId` is used ONLY by the syncer (via
/// `InfrastructureModel.fromDrift`) to build server URLs — it never
/// surfaces through this repository's presentation.
class InfrastructureRepositoryImpl
    with OfflineRepositoryMixin
    implements InfrastructureRepository {
  InfrastructureRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });
  final InfrastructureRemoteDataSource remoteDataSource;
  final InfrastructureLocalDataSource? local;
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
  String get syncEntity => 'infrastructure';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  Infrastructure _toInfrastructure(InfrastructureModel model) =>
      Infrastructure(
        id: model.clientUuid,
        userId: model.userId,
        type: model.type,
        name: model.name,
        location: model.location,
        cost: model.cost,
        date: model.date,
        notes: model.notes,
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
      );

  @override
  Stream<List<Infrastructure>> watchInfrastructures() {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(local!.watchInfrastructures(), _toInfrastructure);
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetInfrastructuresEvent` path) — this only needs to
    // compile and never crash. A single-emission stream mirroring
    // `getInfrastructures()` does that without adding a second remote-fetch
    // code path.
    return Stream.fromFuture(
      getInfrastructures().then(
        (result) =>
            result.fold((_) => <Infrastructure>[], (items) => items),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Infrastructure>>> getInfrastructures() async {
    if (_offlineFirst) {
      final models = await local!.watchInfrastructures().first;
      return Right(models.map(_toInfrastructure).toList());
    }
    try {
      final list = await remoteDataSource.getInfrastructures();
      return Right(list);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Infrastructure>> addInfrastructure(
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String userId,
    String? notes,
  ) async {
    if (_offlineFirst) {
      final model = InfrastructureModel.create(
        userId: userId,
        type: type,
        name: name,
        location: location,
        cost: cost,
        date: date,
        notes: notes,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return Right(_toInfrastructure(model));
    }

    try {
      final model = InfrastructureModel.create(
        userId: userId,
        type: type,
        name: name,
        location: location,
        cost: cost,
        date: date,
        notes: notes,
      );
      final result = await remoteDataSource.addInfrastructure(model);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Infrastructure>> updateInfrastructure(
    String id,
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String? notes,
  ) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      final existing = await local!.getByClientUuid(id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = InfrastructureModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: id,
        userId: existing.userId,
        type: type,
        name: name,
        location: location,
        cost: cost,
        date: date,
        notes: notes ?? '',
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        pending: true,
      );
      await stageWrite(
        local!,
        updated,
        jsonEncode(updated.toJson()),
        OutboxOp.update,
      );
      return Right(_toInfrastructure(updated));
    }

    try {
      final items = await remoteDataSource.getInfrastructures();
      final existing = items.firstWhere((item) => item.id == id);
      final updatedModel = InfrastructureModel(
        id: existing.id,
        userId: existing.userId,
        type: type,
        name: name,
        location: location,
        cost: cost,
        date: date,
        notes: notes ?? '',
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      final result = await remoteDataSource.updateInfrastructure(updatedModel);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInfrastructure(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    try {
      await remoteDataSource.deleteInfrastructure(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
