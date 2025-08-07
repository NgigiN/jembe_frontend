import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/season.dart';
import '../repositories/season_repository.dart';

class GetSeasons implements UseCase<List<Season>, NoParams> {
  final SeasonRepository repository;

  GetSeasons(this.repository);

  @override
  Future<Either<Failure, List<Season>>> call(NoParams params) async {
    return await repository.getSeasons();
  }
}
