import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';

abstract class HarvestRepository {
  /// [limit]/[cursor] drive the online infinite-scroll list path (P3-02a):
  /// they are threaded through only when the offline flag is off. The offline
  /// (`watchHarvests`) path ignores them — it mirrors the whole local store.
  Future<Either<Failure, List<Harvest>>> getHarvests({
    String? seasonId,
    int? limit,
    int? cursor,
  });

  /// Reactive stream of harvests, optionally scoped to [seasonId] (mirrors
  /// the existing `getHarvests(seasonId:)` app-level filter).
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`HarvestLocalDataSource.watchHarvests`), with every
  /// [Harvest.id] equal to the row's stable `clientUuid` — see
  /// `HarvestRepositoryImpl` for why presentation keys on `clientUuid`
  /// rather than the server id. When the flag is off, this is unused by the
  /// app today; it still returns a single-emission stream so callers
  /// compile against one contract either way.
  Stream<List<Harvest>> watchHarvests({String? seasonId});
  Future<Either<Failure, Harvest>> addHarvest(Harvest harvest);
  Future<Either<Failure, Harvest>> updateHarvest(Harvest harvest);
  Future<Either<Failure, void>> deleteHarvest(String id);
}
