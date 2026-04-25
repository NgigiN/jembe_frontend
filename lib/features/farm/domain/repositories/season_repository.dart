import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';

abstract class SeasonRepository {
  Future<Either<Failure, List<Season>>> getSeasons();
  Future<Either<Failure, Season>> addSeason(Season season);
  Future<Either<Failure, Season>> updateSeason(Season season);
  Future<Either<Failure, void>> deleteSeason(String id);
}
