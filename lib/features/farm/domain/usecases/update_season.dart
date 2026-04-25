import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';

class UpdateSeason implements UseCase<Season, UpdateSeasonParams> {
  UpdateSeason(this.repository);
  final SeasonRepository repository;

  @override
  Future<Either<Failure, Season>> call(UpdateSeasonParams params) async {
    return repository.updateSeason(params.season);
  }
}

class UpdateSeasonParams {
  UpdateSeasonParams({required this.season});
  final Season season;
}
