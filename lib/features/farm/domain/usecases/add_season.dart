import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';

class AddSeason implements UseCase<Season, AddSeasonParams> {
  AddSeason(this.repository);
  final SeasonRepository repository;

  @override
  Future<Either<Failure, Season>> call(AddSeasonParams params) async {
    return repository.addSeason(params.season);
  }
}

class AddSeasonParams {
  AddSeasonParams({required this.season});
  final Season season;
}
