import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';

class UpdateInfrastructure {
  UpdateInfrastructure(this.repository);
  final InfrastructureRepository repository;

  Future<Either<Failure, Infrastructure>> call(
    String id,
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String? notes,
  ) async {
    return repository.updateInfrastructure(
      id,
      type,
      name,
      location,
      cost,
      date,
      notes,
    );
  }
}
