import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';

abstract class SeasonRepository {
  Future<Either<Failure, List<Season>>> getSeasons();

  /// Reactive stream of seasons.
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`SeasonLocalDataSource.watchSeasons`), with every [Season.id]
  /// equal to the row's stable `clientUuid` — see `SeasonRepositoryImpl` for
  /// why presentation keys on `clientUuid` rather than the server id. When
  /// the flag is off, this is unused by the app today; it still returns a
  /// single-emission stream so callers compile against one contract either
  /// way.
  Stream<List<Season>> watchSeasons();
  Future<Either<Failure, Season>> addSeason(Season season);
  Future<Either<Failure, Season>> updateSeason(Season season);
  Future<Either<Failure, void>> deleteSeason(String id);
}
