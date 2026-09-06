import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';

abstract class HarvestRepository {
  Future<Either<Failure, List<Harvest>>> getHarvests({String? seasonId});

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