import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';

class DeleteSeason implements UseCase<void, DeleteSeasonParams> {
  DeleteSeason(this.repository);
  final SeasonRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteSeasonParams params) async {
    return repository.deleteSeason(params.id);
  }
}

class DeleteSeasonParams {
  DeleteSeasonParams({required this.id});
  final String id;
}
