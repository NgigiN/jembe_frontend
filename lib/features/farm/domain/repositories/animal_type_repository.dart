import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';

abstract class AnimalTypeRepository {
  Future<Either<Failure, List<AnimalType>>> getAnimalTypes();
  Future<Either<Failure, AnimalType>> getAnimalType(String id);
  Future<Either<Failure, AnimalType>> addAnimalType(
    String name,
    String? notes,
    String userId,
  );
  Future<Either<Failure, AnimalType>> updateAnimalType(
    String id,
    String name,
    String? notes,
  );
  Future<Either<Failure, void>> deleteAnimalType(String id);
}
