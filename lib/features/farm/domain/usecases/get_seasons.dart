import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';

class GetSeasons implements UseCase<List<Season>, NoParams> {
  GetSeasons(this.repository);
  final SeasonRepository repository;

  @override
  Future<Either<Failure, List<Season>>> call(NoParams params) async {
    return repository.getSeasons();
  }
}
