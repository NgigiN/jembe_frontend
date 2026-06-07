import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';

abstract class InfrastructureRepository {
  Future<Either<Failure, List<Infrastructure>>> getInfrastructures();
  Future<Either<Failure, Infrastructure>> addInfrastructure(
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String userId,
    String? notes,
  );
  Future<Either<Failure, Infrastructure>> updateInfrastructure(
    String id,
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String? notes,
  );
  Future<Either<Failure, void>> deleteInfrastructure(String id);
}
