import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/outbox_coalescing.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [LandRepository].
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
/// When the flag is on, every domain [Land] this repository hands out has
/// **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updateLand] and [deleteLand] therefore treat the incoming
/// `id`/`land.id` as a `clientUuid`, never a server id. The drift row's
/// nullable `serverId` is used ONLY by the syncer (via `LandModel.fromDrift`)
/// to build server URLs — it never surfaces through this repository's
/// presentation.
class LandRepositoryImpl implements LandRepository {
  LandRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });

  final LandRemoteDataSource remoteDataSource;
  final LandLocalDataSource? local;
  final OutboxDao? outbox;
  final SyncEngine? sync;
  final UuidGen uuid;

  /// True only when the flag is on AND every offline collaborator this
  /// repository needs for the local-first path was actually supplied.
  /// Falling back to the flag-off (remote) path if any is missing keeps a
  /// half-wired repository safe rather than crashing on a null dependency.
  bool get _offlineFirst =>
      OfflineConfig.enabled && local != null && outbox != null && sync != null;

  Land _toLand(LandModel model) => Land(
    id: model.clientUuid,
    userId: model.userId,
    name: model.name,
    size: model.size,
    location: model.location,
    soilType: model.soilType,
    tenureType: model.tenureType,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  @override
  Stream<List<Land>> watchLands() {
    if (OfflineConfig.enabled && local != null) {
      return local!.watchLands().map((models) => models.map(_toLand).toList());
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetLandsEvent` path) — this only needs to compile and
    // never crash. A single-emission stream mirroring `getLands()` does
    // that without adding a second remote-fetch code path.
    return Stream.fromFuture(
      getLands().then(
        (result) => result.fold((_) => <Land>[], (lands) => lands),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Land>>> getLands() async {
    if (_offlineFirst) {
      final models = await local!.watchLands().first;
      return Right(models.map(_toLand).toList());
    }
    try {
      final lands = await remoteDataSource.getLands();
      return Right(lands);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Land>> addLand(Land land) async {
    if (_offlineFirst) {
      final model = LandModel.create(
        userId: land.userId,
        name: land.name,
        size: land.size,
        location: land.location,
        soilType: land.soilType,
        tenureType: land.tenureType,
        uuid: uuid,
      );
      await local!.upsert(model, pending: true);
      await outbox!.enqueue(
        OutboxIntent(
          op: OutboxOp.create,
          entity: 'land',
          clientUuid: model.clientUuid,
          payload: jsonEncode(model.toJson()),
        ),
      );
      unawaited(sync!.syncNow());
      return Right(_toLand(model));
    }

    try {
      // Use the create factory method to convert Land entity to LandModel
      final landModel = LandModel.create(
        userId: land.userId,
        name: land.name,
        size: land.size,
        location: land.location,
        soilType: land.soilType,
        tenureType: land.tenureType,
      );

      final result = await remoteDataSource.addLand(landModel);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Land>> updateLand(Land land) async {
    if (_offlineFirst) {
      // `land.id` is a clientUuid (presentation identity) — see class docs.
      final existing = await local!.getByClientUuid(land.id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = LandModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: land.id,
        userId: land.userId,
        name: land.name,
        size: land.size,
        location: land.location,
        soilType: land.soilType,
        tenureType: land.tenureType,
        createdAt: land.createdAt,
        updatedAt: DateTime.now(),
        pending: true,
      );
      await local!.upsert(updated, pending: true);
      await outbox!.enqueue(
        OutboxIntent(
          op: OutboxOp.update,
          entity: 'land',
          clientUuid: land.id,
          payload: jsonEncode(updated.toJson()),
        ),
      );
      unawaited(sync!.syncNow());
      return Right(land);
    }

    try {
      // Convert Land entity to LandModel
      final landModel = LandModel(
        id: land.id,
        userId: land.userId,
        name: land.name,
        size: land.size,
        location: land.location,
        soilType: land.soilType,
        tenureType: land.tenureType,
        createdAt: land.createdAt,
        updatedAt: land.updatedAt,
      );

      final result = await remoteDataSource.updateLand(landModel);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteLand(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await local!.markDeleted(id);
      await outbox!.enqueue(
        OutboxIntent(op: OutboxOp.delete, entity: 'land', clientUuid: id),
      );
      unawaited(sync!.syncNow());
      return const Right(null);
    }

    try {
      await remoteDataSource.deleteLand(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
