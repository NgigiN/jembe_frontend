import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';

class DeleteInfrastructure {
  DeleteInfrastructure(this.repository);
  final InfrastructureRepository repository;

  Future<Either<Failure, void>> call(String id) async {
    return repository.deleteInfrastructure(id);
  }
}
