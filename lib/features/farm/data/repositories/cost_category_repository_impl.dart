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
import 'package:farm_tracker/features/farm/data/datasources/cost_category_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/cost_category_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';
import 'package:farm_tracker/features/farm/domain/repositories/cost_category_repository.dart';

/// Live-HTTP (flag off) or local-first read-through cache (flag on)
/// implementation of [CostCategoryRepository].
///
/// `cost_category` is the P3 outlier: NO reactive watch, NO primary-page
/// gate. `CostCategoryBloc` is an app-wide singleton loaded as a one-shot
/// dependency dropdown on `input_page`/`activity_page` — so flag-on,
/// [getCostCategories] simply reads the local mirror once (read-through),
/// rather than subscribing to a stream. Writes land on [local] first, get
/// queued on [outbox] for the bespoke `CostCategorySyncer` to push, and kick
/// off a background [sync] pass — all before this method returns.
///
/// ## Flag off (today's behavior — byte for byte)
/// Every method talks straight to [remoteDataSource], mapping
/// `NetworkException`/`ServerException` to [NetworkFailure]/[ServerFailure].
/// This is rule zero for the offline rollout: with
/// `OfflineConfig.enabled == false`, this class behaves exactly as it did
/// before the offline pipeline existed.
///
/// ### Presentation identity
/// When the flag is on, [addCostCategory] returns `Right(true)` — same
/// shape as today — after staging the local write; it does NOT return the
/// created row (this entity's domain repository never did: the server's
/// create endpoint itself returns only a bool, not the created row — see
/// `CostCategorySyncer`). There is no `updateCostCategory` (the repo never
/// had one).
class CostCategoryRepositoryImpl
    with OfflineRepositoryMixin
    implements CostCategoryRepository {
  CostCategoryRepositoryImpl({
    required this.remoteDataSource,
    this.local,
    this.outbox,
    this.sync,
    this.uuid = const UuidGen(),
  });
  final CostCategoryRemoteDataSource remoteDataSource;
  final CostCategoryLocalDataSource? local;
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
  String get syncEntity => 'cost_category';
  @override
  OutboxDao? get syncOutbox => outbox;
  @override
  SyncEngine? get syncEngine => sync;

  CostCategory _toCostCategory(CostCategoryModel model) => CostCategory(
    id: model.clientUuid,
    name: model.name,
    type: model.type,
    category: model.category,
    isDefault: model.isDefault,
  );

  @override
  Future<Either<Failure, List<CostCategory>>> getCostCategories({
    String? type,
    String? category,
  }) async {
    if (_offlineFirst) {
      final models = await local!.getCostCategories(
        type: type,
        category: category,
      );
      return Right(models.map(_toCostCategory).toList());
    }
    try {
      final remoteCategories = await remoteDataSource.getCostCategories(
        type: type,
        category: category,
      );
      return Right(remoteCategories);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> addCostCategory({
    required String name,
    required String type,
    required String category,
  }) async {
    if (_offlineFirst) {
      final model = CostCategoryModel.create(
        name: name,
        type: type,
        category: category,
        uuid: uuid,
      );
      await stageWrite(
        local!,
        model,
        jsonEncode(model.toJson()),
        OutboxOp.create,
      );
      return const Right(true);
    }
    try {
      final success = await remoteDataSource.addCostCategory(
        name: name,
        type: type,
        category: category,
      );
      return Right(success);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCostCategory(String id) async {
    if (_offlineFirst) {
      // `id` is a clientUuid (presentation identity) — see class docs.
      await stageDelete(local!, id);
      return const Right(null);
    }
    try {
      await remoteDataSource.deleteCostCategory(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
