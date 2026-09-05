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
import 'package:farm_tracker/features/farm/data/datasources/animal_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [AnimalRepository].
///
/// ## Flag off (today's behavior — byte for byte)
/// Every method talks straight to [remoteDataSource], mapping
/// [NetworkException]/[ServerException] to [NetworkFailure]/[ServerFailure].
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
/// When the flag is on, every domain [Animal] this repository hands out has
/// **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updateAnimal] and [deleteAnimal] therefore treat the incoming
/// `id`/`animal.id` as a `clientUuid`, never a server id. The drift row's
/// nullable `serverId` is used ONLY by the syncer (via `AnimalModel.fromDrift`)
/// to build server URLs — it never surfaces through this repository's
/// presentation.
class AnimalRepositoryImpl
    with OfflineRepositoryMixin
    implements AnimalRepository {
  AnimalRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });

  final AnimalRemoteDataSource remoteDataSource;
  final AnimalLocalDataSource? local;
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
  String get syncEntity => 'animal';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  Animal _toAnimal(AnimalModel model) => Animal(
    id: model.clientUuid,
    userId: model.userId,
    name: model.name,
    animalTypeId: model.animalTypeId,
    herdId: model.herdId,
    birthDate: model.birthDate,
    sex: model.sex,
    acquisitionSource: model.acquisitionSource,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  @override
  Stream<List<Animal>> watchAnimals() {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(local!.watchAnimals(), _toAnimal);
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetAnimalsEvent` path) — this only needs to compile
    // and never crash. A single-emission stream mirroring `getAnimals()`
    // does that without adding a second remote-fetch code path.
    return Stream.fromFuture(
      getAnimals().then(
        (result) => result.fold((_) => <Animal>[], (animals) => animals),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Animal>>> getAnimals() async {
    if (_offlineFirst) {
      final models = await local!.watchAnimals().first;
      return Right(models.map(_toAnimal).toList());
    }
    try {
      final animals = await remoteDataSource.getAnimals();
      return Right(animals);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Animal>> addAnimal(Animal animal) async {
    if (_offlineFirst) {
      final model = AnimalModel.create(
        userId: animal.userId,
        name: animal.name,
        animalTypeId: animal.animalTypeId,
        herdId: animal.herdId,
        birthDate: animal.birthDate,
        sex: animal.sex,
        acquisitionSource: animal.acquisitionSource,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return Right(_toAnimal(model));
    }

    try {
      final animalModel = AnimalModel.create(
        userId: animal.userId,
        name: animal.name,
        animalTypeId: animal.animalTypeId,
        herdId: animal.herdId,
        birthDate: animal.birthDate,
        sex: animal.sex,
        acquisitionSource: animal.acquisitionSource,
      );

      final result = await remoteDataSource.addAnimal(animalModel);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Animal>> updateAnimal(Animal animal) async {
    if (_offlineFirst) {
      // `animal.id` is a clientUuid (presentation identity) — see class
      // docs.
      final existing = await local!.getByClientUuid(animal.id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = AnimalModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: animal.id,
        userId: animal.userId,
        name: animal.name,
        animalTypeId: animal.animalTypeId,
        herdId: animal.herdId,
        birthDate: animal.birthDate,
        sex: animal.sex,
        acquisitionSource: animal.acquisitionSource,
        createdAt: animal.createdAt,
        updatedAt: DateTime.now(),
        pending: true,
      );
      await stageWrite(
        local!,
        updated,
        jsonEncode(updated.toJson()),
        OutboxOp.update,
      );
      return Right(animal);
    }

    try {
      final animalModel = AnimalModel(
        id: animal.id,
        userId: animal.userId,
        name: animal.name,
        animalTypeId: animal.animalTypeId,
        herdId: animal.herdId,
        birthDate: animal.birthDate,
        sex: animal.sex,
        acquisitionSource: animal.acquisitionSource,
        createdAt: animal.createdAt,
        updatedAt: animal.updatedAt,
      );
      final result = await remoteDataSource.updateAnimal(animalModel);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAnimal(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    try {
      await remoteDataSource.deleteAnimal(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
