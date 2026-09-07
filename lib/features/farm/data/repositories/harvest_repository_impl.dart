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
import 'package:farm_tracker/features/farm/data/datasources/harvest_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [HarvestRepository].
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
/// When the flag is on, every domain [Harvest] this repository hands out
/// has **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updateHarvest] and [deleteHarvest] therefore treat the
/// incoming `id`/`harvest.id` as a `clientUuid`, never a server id. The
/// drift row's nullable `serverId` is used ONLY by the syncer (via
/// `HarvestModel.fromDrift`) to build server URLs — it never surfaces
/// through this repository's presentation.
class HarvestRepositoryImpl
    with OfflineRepositoryMixin
    implements HarvestRepository {
  HarvestRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });

  final HarvestRemoteDataSource remoteDataSource;
  final HarvestLocalDataSource? local;
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
  String get syncEntity => 'harvest';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  HarvestModel _toModel(Harvest harvest) {
    return HarvestModel(
      id: harvest.id,
      seasonId: harvest.seasonId,
      quantity: harvest.quantity,
      unit: harvest.unit,
      date: harvest.date,
      notes: harvest.notes,
      revenueId: harvest.revenueId,
      createdAt: harvest.createdAt,
      updatedAt: harvest.updatedAt,
    );
  }

  Harvest _toHarvest(HarvestModel model) => Harvest(
    id: model.clientUuid,
    seasonId: model.seasonId,
    quantity: model.quantity,
    unit: model.unit,
    date: model.date,
    notes: model.notes,
    revenueId: model.revenueId,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  @override
  Stream<List<Harvest>> watchHarvests({String? seasonId}) {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(
        local!.watchHarvests(seasonId: seasonId),
        _toHarvest,
      );
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetHarvestsEvent` path) — this only needs to compile
    // and never crash. A single-emission stream mirroring `getHarvests()`
    // does that without adding a second remote-fetch code path.
    return Stream.fromFuture(
      getHarvests(seasonId: seasonId).then(
        (result) => result.fold((_) => <Harvest>[], (harvests) => harvests),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Harvest>>> getHarvests({
    String? seasonId,
  }) async {
    if (_offlineFirst) {
      final models = await local!.watchHarvests(seasonId: seasonId).first;
      return Right(models.map(_toHarvest).toList());
    }
    try {
      final harvests = await remoteDataSource.getHarvests(seasonId: seasonId);
      return Right(harvests);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Harvest>> addHarvest(Harvest harvest) async {
    if (_offlineFirst) {
      final model = HarvestModel.create(
        seasonId: harvest.seasonId,
        quantity: harvest.quantity,
        unit: harvest.unit,
        date: harvest.date,
        notes: harvest.notes,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return Right(_toHarvest(model));
    }

    try {
      final result = await remoteDataSource.addHarvest(_toModel(harvest));
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Harvest>> updateHarvest(Harvest harvest) async {
    if (_offlineFirst) {
      // `harvest.id` is a clientUuid (presentation identity) — see class
      // docs.
      final existing = await local!.getByClientUuid(harvest.id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = HarvestModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: harvest.id,
        seasonId: harvest.seasonId,
        quantity: harvest.quantity,
        unit: harvest.unit,
        date: harvest.date,
        notes: harvest.notes,
        revenueId: harvest.revenueId,
        createdAt: harvest.createdAt,
        updatedAt: DateTime.now(),
        pending: true,
      );
      await stageWrite(
        local!,
        updated,
        jsonEncode(updated.toJson()),
        OutboxOp.update,
      );
      return Right(harvest);
    }

    try {
      final result = await remoteDataSource.updateHarvest(_toModel(harvest));
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteHarvest(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    try {
      await remoteDataSource.deleteHarvest(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
