import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/offline/offline_repository.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/outbox_coalescing.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/core/utils/guard.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [SeasonRepository].
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
/// When the flag is on, every domain [Season] this repository hands out has
/// **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updateSeason] and [deleteSeason] therefore treat the incoming
/// `id`/`season.id` as a `clientUuid`, never a server id. The drift row's
/// nullable `serverId` is used ONLY by the syncer (via
/// `SeasonModel.fromDrift`) to build server URLs — it never surfaces
/// through this repository's presentation.
///
/// ### FK note
/// `plantId`/`landId` are passed through as-is here — this repository stages
/// the mutation locally with whatever ids it's given (a synced parent's
/// server id or an unsynced parent's client_uuid). The syncer's
/// `translateSeasonFks` (`fk_translators.dart`) resolves an unsynced
/// parent's client_uuid to its server id at push time via
/// `BaseEntitySyncer.resolveFks`.
class SeasonRepositoryImpl
    with OfflineRepositoryMixin
    implements SeasonRepository {
  SeasonRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });

  final SeasonRemoteDataSource remoteDataSource;
  final SeasonLocalDataSource? local;
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
  String get syncEntity => 'season';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  Season _toSeason(SeasonModel model) => Season(
    id: model.clientUuid,
    userId: model.userId,
    name: model.name,
    plantId: model.plantId,
    landId: model.landId,
    startDate: model.startDate,
    endDate: model.endDate,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  @override
  Stream<List<Season>> watchSeasons() {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(local!.watchSeasons(), _toSeason);
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `GetSeasonsEvent` path) — this only needs to compile
    // and never crash. A single-emission stream mirroring `getSeasons()`
    // does that without adding a second remote-fetch code path.
    return Stream.fromFuture(
      getSeasons().then(
        (result) => result.fold((_) => <Season>[], (seasons) => seasons),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Season>>> getSeasons() async {
    if (_offlineFirst) {
      final models = await local!.watchSeasons().first;
      return Right(models.map(_toSeason).toList());
    }
    return guard(remoteDataSource.getSeasons);
  }

  @override
  Future<Either<Failure, Season>> addSeason(Season season) async {
    if (_offlineFirst) {
      final model = SeasonModel.create(
        userId: season.userId,
        name: season.name,
        plantId: season.plantId,
        landId: season.landId,
        startDate: season.startDate,
        endDate: season.endDate,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return Right(_toSeason(model));
    }

    return guard(() {
      // Convert Season entity to SeasonModel
      final seasonModel = SeasonModel(
        id: season.id,
        userId: season.userId,
        name: season.name,
        plantId: season.plantId,
        landId: season.landId,
        startDate: season.startDate,
        endDate: season.endDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return remoteDataSource.addSeason(seasonModel);
    });
  }

  @override
  Future<Either<Failure, void>> deleteSeason(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    return guard(() => remoteDataSource.deleteSeason(id));
  }

  @override
  Future<Either<Failure, Season>> updateSeason(Season season) async {
    if (_offlineFirst) {
      // `season.id` is a clientUuid (presentation identity) — see class
      // docs.
      final existing = await local!.getByClientUuid(season.id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = SeasonModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: season.id,
        userId: season.userId,
        name: season.name,
        plantId: season.plantId,
        landId: season.landId,
        startDate: season.startDate,
        endDate: season.endDate,
        createdAt: season.createdAt,
        updatedAt: DateTime.now(),
        pending: true,
      );
      await stageWrite(
        local!,
        updated,
        jsonEncode(updated.toJson()),
        OutboxOp.update,
      );
      return Right(season);
    }

    return guard(() {
      final seasonModel = SeasonModel(
        id: season.id,
        userId: season.userId,
        name: season.name,
        plantId: season.plantId,
        landId: season.landId,
        startDate: season.startDate,
        endDate: season.endDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return remoteDataSource.updateSeason(seasonModel);
    });
  }
}
