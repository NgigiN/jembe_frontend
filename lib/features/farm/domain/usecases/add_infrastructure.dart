import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';

class AddInfrastructure {
  AddInfrastructure(this.repository);
  final InfrastructureRepository repository;

  Future<Either<Failure, Infrastructure>> call(
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String userId,
    String? notes,
  ) async {
    return repository.addInfrastructure(
      type,
      name,
      location,
      cost,
      date,
      userId,
      notes,
    );
  }
}
