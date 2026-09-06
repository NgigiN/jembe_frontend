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
import 'package:farm_tracker/features/farm/data/datasources/revenue_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';

/// Live-HTTP (flag off) or local-first + outbox (flag on) implementation of
/// [RevenueRepository].
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
/// When the flag is on, every domain [Revenue] this repository hands out
/// has **`id` == the local row's `clientUuid`** — the stable identity that
/// exists offline and never changes when the row later syncs and gains a
/// server id. [updateRevenue], [deleteRevenue] and [getRevenueById]
/// therefore treat the incoming `id` as a `clientUuid`, never a server id.
/// The drift row's nullable `serverId` is used ONLY by the syncer (via
/// `RevenueModel.fromDrift`) to build server URLs — it never surfaces
/// through this repository's presentation.
///
/// ### FK note (P3 scope)
/// `sourceId` is passed through as-is — see the `// TODO(P4)` note in
/// `revenue_model.dart`. This repository supports create/update only for a
/// revenue whose parent source (season/herd) is already synced (has a
/// server id); reconciling an unsynced parent's clientUuid into a server id
/// is P4 work.
class RevenueRepositoryImpl
    with OfflineRepositoryMixin
    implements RevenueRepository {
  RevenueRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });
  final RevenueRemoteDataSource remoteDataSource;
  final RevenueLocalDataSource? local;
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
  String get syncEntity => 'revenue';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  Revenue _toRevenue(RevenueModel model) => Revenue(
    id: model.clientUuid,
    userId: model.userId,
    source: model.source,
    sourceId: model.sourceId,
    type: model.type,
    quantity: model.quantity,
    unitPrice: model.unitPrice,
    total: model.total,
    date: model.date,
    notes: model.notes,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
  );

  /// Applies the same `source`/date-range predicate the server's filtered
  /// `getRevenues` endpoint uses — inclusive on both ends of the date
  /// range. Mirrors `RevenueBloc`'s in-memory filter (kept in sync
  /// deliberately, one small predicate each, rather than sharing code
  /// across the data/presentation layer boundary).
  bool _matchesFilter(
    Revenue revenue, {
    String? source,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (source != null && revenue.source != source) return false;
    if (startDate != null && revenue.date.isBefore(startDate)) return false;
    if (endDate != null && revenue.date.isAfter(endDate)) return false;
    return true;
  }

  @override
  Stream<List<Revenue>> watchRevenues() {
    if (OfflineConfig.enabled && local != null) {
      return watchAsDomain(local!.watchRevenues(), _toRevenue);
    }
    // Unused by the app while the flag is off (the bloc keeps its
    // remote-polling `LoadRevenues` path) — this only needs to compile and
    // never crash. A single-emission stream mirroring `getRevenues()` does
    // that without adding a second remote-fetch code path.
    return Stream.fromFuture(
      getRevenues().then(
        (result) => result.fold((_) => <Revenue>[], (revenues) => revenues),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Revenue>>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_offlineFirst) {
      final models = await local!.watchRevenues().first;
      final revenues = models
          .map(_toRevenue)
          .where(
            (r) => _matchesFilter(
              r,
              source: source,
              startDate: startDate,
              endDate: endDate,
            ),
          )
          .toList();
      return Right(revenues);
    }
    try {
      final revenues = await remoteDataSource.getRevenues(
        source: source,
        startDate: startDate,
        endDate: endDate,
      );
      return Right(revenues);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Revenue>> getRevenueById(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      final model = await local!.getByClientUuid(id);
      if (model == null) {
        return const Left(CacheFailure());
      }
      return Right(_toRevenue(model));
    }
    try {
      final revenue = await remoteDataSource.getRevenueById(id);
      return Right(revenue);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Revenue>> addRevenue({
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required DateTime date,
    double? total,
    String? notes,
  }) async {
    if (_offlineFirst) {
      final model = RevenueModel.create(
        source: source,
        sourceId: sourceId,
        type: type,
        quantity: quantity,
        unitPrice: unitPrice,
        total: total,
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
      return Right(_toRevenue(model));
    }

    try {
      final revenueModel = RevenueModel.create(
        source: source,
        sourceId: sourceId,
        type: type,
        quantity: quantity,
        unitPrice: unitPrice,
        total: total,
        date: date,
        notes: notes,
      );
      final revenue = await remoteDataSource.addRevenue(revenueModel);
      return Right(revenue);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Revenue>> updateRevenue({
    required String id,
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required double total,
    required DateTime date,
    String? notes,
  }) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      final existing = await local!.getByClientUuid(id);
      if (existing == null) {
        return const Left(CacheFailure());
      }
      final updated = RevenueModel(
        id: existing.id, // preserve the serverId so the syncer can PUT.
        clientUuid: id,
        userId: existing.userId,
        source: source,
        sourceId: sourceId,
        type: type,
        quantity: quantity,
        unitPrice: unitPrice,
        total: total,
        date: date,
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
      return Right(_toRevenue(updated));
    }

    try {
      final revenueModel = RevenueModel(
        id: id,
        userId: '',
        source: source,
        sourceId: sourceId,
        type: type,
        quantity: quantity,
        unitPrice: unitPrice,
        total: total,
        date: date,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final revenue = await remoteDataSource.updateRevenue(revenueModel);
      return Right(revenue);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRevenue(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }

    try {
      await remoteDataSource.deleteRevenue(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
