import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/season_repository.dart';

class DeleteSeason implements UseCase<void, DeleteSeasonParams> {
  final SeasonRepository repository;

  DeleteSeason(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteSeasonParams params) async {
    return await repository.deleteSeason(params.id);
  }
}

class DeleteSeasonParams {
  final String id;

  DeleteSeasonParams({required this.id});
}
