import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';

abstract class LandRepository {
  Future<Either<Failure, List<Land>>> getLands();

  /// Reactive stream of lands.
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`LandLocalDataSource.watchLands`), with every [Land.id] equal
  /// to the row's stable `clientUuid` — see `LandRepositoryImpl` for why
  /// presentation keys on `clientUuid` rather than the server id. When the
  /// flag is off, this is unused by the app today; it still returns a
  /// single-emission stream so callers compile against one contract either
  /// way.
  Stream<List<Land>> watchLands();
  Future<Either<Failure, Land>> addLand(Land land);
  Future<Either<Failure, Land>> updateLand(Land land);
  Future<Either<Failure, void>> deleteLand(String id);
}
