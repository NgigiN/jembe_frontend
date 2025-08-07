import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/season.dart';
import '../repositories/season_repository.dart';

class AddSeason implements UseCase<Season, AddSeasonParams> {
  final SeasonRepository repository;

  AddSeason(this.repository);

  @override
  Future<Either<Failure, Season>> call(AddSeasonParams params) async {
    return await repository.addSeason(params.season);
  }
}

class AddSeasonParams {
  final Season season;

  AddSeasonParams({required this.season});
}
