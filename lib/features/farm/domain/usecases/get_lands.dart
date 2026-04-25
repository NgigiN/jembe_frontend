import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';

class GetLands implements UseCase<List<Land>, NoParams> {
  GetLands(this.repository);
  final LandRepository repository;

  @override
  Future<Either<Failure, List<Land>>> call(NoParams params) async {
    return repository.getLands();
  }
}
