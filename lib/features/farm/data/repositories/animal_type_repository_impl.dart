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
import 'package:farm_tracker/features/farm/data/datasources/animal_type_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_type_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [AnimalTypeRepository].
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
/// When the flag is on, every domain [AnimalType] this repository hands out
/// has **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updateAnimalType] and [deleteAnimalType] therefore treat the
/// incoming `id` as a `clientUuid`, never a server id. The drift row's
/// nullable `serverId` is used ONLY by the syncer (via
/// `AnimalTypeModel.fromDrift`) to build server URLs — it never surfaces
/// through this repository's presentation.
class AnimalTypeRepositoryImpl
    with OfflineRepositoryMixin
    implements AnimalTypeRepository {
  AnimalTypeRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });
  final AnimalTypeRemoteDataSource remoteDataSource;
  final AnimalTypeLocalDataSource? local;
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
  String get syncEntity => 'animal_type';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  AnimalType _toAnimalType(AnimalTypeModel model) => AnimalType(
    id: model.clientUuid,
    userId: model.userId,
    name: model.name,
    notes: model.notes,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  @override
  Stream<List<AnimalType>> watchAnimalTypes() {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(local!.watchAnimalTypes(), _toAnimalType);
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetAnimalTypesEvent` path) — this only needs to
    // compile and never crash. A single-emission stream mirroring
    // `getAnimalTypes()` does that without adding a second remote-fetch
    // code path.
    return Stream.fromFuture(
      getAnimalTypes().then(
        (result) => result.fold((_) => <AnimalType>[], (types) => types),
      ),
    );
  }

  @override
  Future<Either<Failure, List<AnimalType>>> getAnimalTypes() async {
    if (_offlineFirst) {
      final models = await local!.watchAnimalTypes().first;
      return Right(models.map(_toAnimalType).toList());
    }
    try {
      final animalTypes = await remoteDataSource.getAnimalTypes();
      return Right(animalTypes);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, AnimalType>> getAnimalType(String id) async {
    try {
      final animalType = await remoteDataSource.getAnimalType(id);
      return Right(animalType);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, AnimalType>> addAnimalType(
    String name,
    String? notes,
    String userId,
  ) async {
    if (_offlineFirst) {
      final model = AnimalTypeModel.create(
        userId: userId,
        name: name,
        notes: notes,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return Right(_toAnimalType(model));
    }

    try {
      final animalTypeModel = AnimalTypeModel.create(
        userId: userId,
        name: name,
        notes: notes,
      );
      final result = await remoteDataSource.addAnimalType(animalTypeModel);
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
  Future<Either<Failure, AnimalType>> updateAnimalType(
    String id,
    String name,
    String? notes,
  ) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      final existing = await local!.getByClientUuid(id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = AnimalTypeModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: id,
        userId: existing.userId,
        name: name,
        notes: notes,
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
      return Right(_toAnimalType(updated));
    }

    try {
      final animalTypeModel = await remoteDataSource.getAnimalType(id);
      final updatedModel = AnimalTypeModel(
        id: animalTypeModel.id,
        userId: animalTypeModel.userId,
        name: name,
        notes: notes,
        createdAt: animalTypeModel.createdAt,
        updatedAt: DateTime.now(),
      );
      final result = await remoteDataSource.updateAnimalType(updatedModel);
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
  Future<Either<Failure, void>> deleteAnimalType(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    try {
      await remoteDataSource.deleteAnimalType(id);
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
