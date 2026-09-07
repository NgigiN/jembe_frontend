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
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd_activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_activity_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [HerdActivityRepository].
///
/// `herd_activity` is the P3 outlier: CREATE-ONLY (no list, no update, no
/// delete). Flag-on, [addHerdActivity] stages the create locally and returns
/// immediately — the bespoke `HerdActivitySyncer` pushes it in the
/// background (see its docs for the nested-URL push and the P4
/// retry-duplication note).
///
/// ## Flag off (today's behavior — byte for byte)
/// Talks straight to [remoteDataSource], mapping
/// `NetworkException`/`ServerException` to [NetworkFailure]/[ServerFailure].
/// This is rule zero for the offline rollout: with
/// `OfflineConfig.enabled == false`, this class behaves exactly as it did
/// before the offline pipeline existed.
class HerdActivityRepositoryImpl
    with OfflineRepositoryMixin
    implements HerdActivityRepository {
  HerdActivityRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });
  final HerdActivityRemoteDataSource remoteDataSource;
  final HerdActivityLocalDataSource? local;
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
  String get syncEntity => 'herd_activity';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  @override
  Future<Either<Failure, HerdActivity>> addHerdActivity(
    String herdId,
    String activityType,
    int count,
    DateTime date,
    String? notes,
  ) async {
    if (_offlineFirst) {
      // herdId is passed through as-is here — this repository stages the
      // create locally with whatever id it's given (a synced herd's server
      // id or an unsynced herd's client_uuid). `HerdActivitySyncer.push`
      // resolves an unsynced herd's client_uuid to its server id at push
      // time via `resolveFkOrThrow` before firing the nested-URL create.
      final model = HerdActivityModel.create(
        herdId: herdId,
        activityType: activityType,
        count: count,
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
      return Right(model);
    }
    try {
      final model = HerdActivityModel.create(
        herdId: herdId,
        activityType: activityType,
        count: count,
        date: date,
        notes: notes,
      );
      final result = await remoteDataSource.addHerdActivity(herdId, model);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
