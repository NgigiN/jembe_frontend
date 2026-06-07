import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';

class GetInfrastructure implements UseCase<List<Infrastructure>, NoParams> {
  GetInfrastructure(this.repository);
  final InfrastructureRepository repository;

  @override
  Future<Either<Failure, List<Infrastructure>>> call(NoParams params) async {
    return repository.getInfrastructures();
  }
}
