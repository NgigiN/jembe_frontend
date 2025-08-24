import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/season.dart';
import '../repositories/season_repository.dart';

class UpdateSeason implements UseCase<Season, UpdateSeasonParams> {
  final SeasonRepository repository;

  UpdateSeason(this.repository);

  @override
  Future<Either<Failure, Season>> call(UpdateSeasonParams params) async {
    return await repository.updateSeason(params.season);
  }
}

class UpdateSeasonParams {
  final Season season;

  UpdateSeasonParams({required this.season});
}
