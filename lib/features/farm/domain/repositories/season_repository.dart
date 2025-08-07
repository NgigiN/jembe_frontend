import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/season.dart';

abstract class SeasonRepository {
  Future<Either<Failure, List<Season>>> getSeasons();
  Future<Either<Failure, Season>> addSeason(Season season);
  Future<Either<Failure, Season>> updateSeason(Season season);
  Future<Either<Failure, void>> deleteSeason(String id);
}
