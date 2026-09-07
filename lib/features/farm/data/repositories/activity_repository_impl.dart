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
import 'package:farm_tracker/features/farm/data/datasources/activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [ActivityRepository].
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
/// When the flag is on, every domain [Activity] this repository hands out
/// has **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updateActivity] and [deleteActivity] therefore treat the
/// incoming `id`/`activity.id` as a `clientUuid`, never a server id. The
/// drift row's nullable `serverId` is used ONLY by the syncer (via
/// `ActivityModel.fromDrift`) to build server URLs — it never surfaces
/// through this repository's presentation.
class ActivityRepositoryImpl
    with OfflineRepositoryMixin
    implements ActivityRepository {
  ActivityRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });

  final ActivityRemoteDataSource remoteDataSource;
  final ActivityLocalDataSource? local;
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
  String get syncEntity => 'activity';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  ActivityModel _toModel(Activity activity) {
    return ActivityModel(
      id: activity.id,
      sourceType: activity.sourceType,
      sourceId: activity.sourceId,
      animalId: activity.animalId,
      type: activity.type,
      date: activity.date,
      cost: activity.cost,
      details: activity.details,
      notes: activity.notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Activity _toActivity(ActivityModel model) => Activity(
    id: model.clientUuid,
    sourceType: model.sourceType,
    sourceId: model.sourceId,
    animalId: model.animalId,
    type: model.type,
    details: model.details,
    cost: model.cost,
    date: model.date,
    notes: model.notes,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  @override
  Stream<List<Activity>> watchActivities({String? sourceType}) {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(
        local!.watchActivities(sourceType: sourceType),
        _toActivity,
      );
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetActivitiesEvent` path) — this only needs to
    // compile and never crash. A single-emission stream mirroring
    // `getActivities()` does that without adding a second remote-fetch
    // code path.
    return Stream.fromFuture(
      getActivities(sourceType: sourceType).then(
        (result) => result.fold((_) => <Activity>[], (activities) => activities),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Activity>>> getActivities({
    String? sourceType,
  }) async {
    if (_offlineFirst) {
      final models =
          await local!.watchActivities(sourceType: sourceType).first;
      return Right(models.map(_toActivity).toList());
    }
    try {
      final activities = await remoteDataSource.getActivities(
        sourceType: sourceType,
      );
      return Right(activities);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Activity>> addActivity(Activity activity) async {
    if (_offlineFirst) {
      final model = ActivityModel.create(
        sourceType: activity.sourceType,
        sourceId: activity.sourceId,
        animalId: activity.animalId,
        type: activity.type,
        details: activity.details,
        cost: activity.cost,
        date: activity.date,
        notes: activity.notes,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return Right(_toActivity(model));
    }

    try {
      final result = await remoteDataSource.addActivity(_toModel(activity));
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Activity>> updateActivity(Activity activity) async {
    if (_offlineFirst) {
      // `activity.id` is a clientUuid (presentation identity) — see class
      // docs.
      final existing = await local!.getByClientUuid(activity.id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = ActivityModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: activity.id,
        sourceType: activity.sourceType,
        sourceId: activity.sourceId,
        animalId: activity.animalId,
        type: activity.type,
        details: activity.details,
        cost: activity.cost,
        date: activity.date,
        notes: activity.notes,
        createdAt: activity.createdAt,
        updatedAt: DateTime.now(),
        pending: true,
      );
      await stageWrite(
        local!,
        updated,
        jsonEncode(updated.toJson()),
        OutboxOp.update,
      );
      return Right(activity);
    }

    try {
      final result = await remoteDataSource.updateActivity(
        _toModel(activity),
      );
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteActivity(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    try {
      await remoteDataSource.deleteActivity(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
