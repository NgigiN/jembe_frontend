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
import 'package:farm_tracker/features/farm/data/datasources/herd_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [HerdRepository].
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
/// When the flag is on, every domain [Herd] this repository hands out has
/// **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updateHerd] and [deleteHerd] therefore treat the incoming
/// `id` as a `clientUuid`, never a server id. The drift row's nullable
/// `serverId` is used ONLY by the syncer (via `HerdModel.fromDrift`) to
/// build server URLs — it never surfaces through this repository's
/// presentation.
///
/// ### FK note
/// `animalTypeId` is passed through as-is here — this repository stages the
/// mutation locally with whatever id it's given (a synced parent's server id
/// or an unsynced parent's client_uuid). The syncer's `translateHerdFks`
/// (`fk_translators.dart`) resolves an unsynced parent's client_uuid to its
/// server id at push time via `BaseEntitySyncer.resolveFks`.
class HerdRepositoryImpl with OfflineRepositoryMixin implements HerdRepository {
  HerdRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });
  final HerdRemoteDataSource remoteDataSource;
  final HerdLocalDataSource? local;
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
  String get syncEntity => 'herd';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  Herd _toHerd(HerdModel model) => Herd(
    id: model.clientUuid,
    userId: model.userId,
    name: model.name,
    animalTypeId: model.animalTypeId,
    location: model.location,
    initialHeadCount: model.initialHeadCount,
    currentHeadCount: model.currentHeadCount,
    startDate: model.startDate,
    endDate: model.endDate,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  @override
  Stream<List<Herd>> watchHerds() {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(local!.watchHerds(), _toHerd);
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetHerdsEvent` path) — this only needs to compile and
    // never crash. A single-emission stream mirroring `getHerds()` does
    // that without adding a second remote-fetch code path.
    return Stream.fromFuture(
      getHerds().then(
        (result) => result.fold((_) => <Herd>[], (herds) => herds),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Herd>>> getHerds() async {
    if (_offlineFirst) {
      final models = await local!.watchHerds().first;
      return Right(models.map(_toHerd).toList());
    }
    try {
      final herds = await remoteDataSource.getHerds();
      return Right(herds);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Herd>> addHerd(
    String name,
    String animalTypeId,
    String location,
    String userId,
    int initialHeadCount, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (_offlineFirst) {
      final model = HerdModel.create(
        userId: userId,
        name: name,
        animalTypeId: animalTypeId,
        location: location,
        initialHeadCount: initialHeadCount,
        startDate: startDate,
        endDate: endDate,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return Right(_toHerd(model));
    }

    try {
      final herdModel = HerdModel.create(
        userId: userId,
        name: name,
        animalTypeId: animalTypeId,
        location: location,
        initialHeadCount: initialHeadCount,
        startDate: startDate,
        endDate: endDate,
      );
      final result = await remoteDataSource.addHerd(herdModel);
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
  Future<Either<Failure, Herd>> updateHerd(
    String id,
    String name,
    String animalTypeId,
    String location,
    int initialHeadCount, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      final existing = await local!.getByClientUuid(id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = HerdModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: id,
        userId: existing.userId,
        name: name,
        animalTypeId: animalTypeId,
        location: location,
        initialHeadCount: initialHeadCount,
        currentHeadCount: existing.currentHeadCount,
        startDate: startDate,
        endDate: endDate,
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
      return Right(_toHerd(updated));
    }

    try {
      final herdModel = await remoteDataSource.getHerds();
      final existingHerd = herdModel.firstWhere((h) => h.id == id);
      final updatedModel = HerdModel(
        id: existingHerd.id,
        userId: existingHerd.userId,
        name: name,
        animalTypeId: animalTypeId,
        location: location,
        initialHeadCount: initialHeadCount,
        currentHeadCount: existingHerd.currentHeadCount,
        startDate: startDate,
        endDate: endDate,
        createdAt: existingHerd.createdAt,
        updatedAt: DateTime.now(),
      );
      final result = await remoteDataSource.updateHerd(updatedModel);
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
  Future<Either<Failure, void>> deleteHerd(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    try {
      await remoteDataSource.deleteHerd(id);
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
