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
import 'package:farm_tracker/features/farm/data/datasources/plant_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [PlantRepository].
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
/// When the flag is on, every domain [Plant] this repository hands out has
/// **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updatePlant] and [deletePlant] therefore treat the incoming
/// `id`/`plant.id` as a `clientUuid`, never a server id. The drift row's
/// nullable `serverId` is used ONLY by the syncer (via `PlantModel.fromDrift`)
/// to build server URLs — it never surfaces through this repository's
/// presentation.
class PlantRepositoryImpl
    with OfflineRepositoryMixin
    implements PlantRepository {
  PlantRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });

  final PlantRemoteDataSource remoteDataSource;
  final PlantLocalDataSource? local;
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
  String get syncEntity => 'plant';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  Plant _toPlant(PlantModel model) => Plant(
    id: model.clientUuid,
    userId: model.userId,
    name: model.name,
    variety: model.variety,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  @override
  Stream<List<Plant>> watchPlants() {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(local!.watchPlants(), _toPlant);
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetPlantsEvent` path) — this only needs to compile and
    // never crash. A single-emission stream mirroring `getPlants()` does
    // that without adding a second remote-fetch code path.
    return Stream.fromFuture(
      getPlants().then(
        (result) => result.fold((_) => <Plant>[], (plants) => plants),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Plant>>> getPlants() async {
    if (_offlineFirst) {
      final models = await local!.watchPlants().first;
      return Right(models.map(_toPlant).toList());
    }
    try {
      final plants = await remoteDataSource.getPlants();
      return Right(plants);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Plant>> addPlant(Plant plant) async {
    if (_offlineFirst) {
      final model = PlantModel.create(
        userId: plant.userId,
        name: plant.name,
        variety: plant.variety,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return Right(_toPlant(model));
    }

    try {
      final plantModel = PlantModel.create(
        userId: plant.userId,
        name: plant.name,
        variety: plant.variety,
      );

      final result = await remoteDataSource.addPlant(plantModel);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Plant>> updatePlant(Plant plant) async {
    if (_offlineFirst) {
      // `plant.id` is a clientUuid (presentation identity) — see class docs.
      final existing = await local!.getByClientUuid(plant.id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = PlantModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: plant.id,
        userId: plant.userId,
        name: plant.name,
        variety: plant.variety,
        createdAt: plant.createdAt,
        updatedAt: DateTime.now(),
        pending: true,
      );
      await stageWrite(
        local!,
        updated,
        jsonEncode(updated.toJson()),
        OutboxOp.update,
      );
      return Right(plant);
    }

    try {
      final plantModel = PlantModel(
        id: plant.id,
        userId: plant.userId,
        name: plant.name,
        variety: plant.variety,
        createdAt: plant.createdAt,
        updatedAt: plant.updatedAt,
      );
      final result = await remoteDataSource.updatePlant(plantModel);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deletePlant(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    try {
      await remoteDataSource.deletePlant(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
