import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

abstract class AnimalRepository {
  Future<Either<Failure, List<Animal>>> getAnimals();
  Future<Either<Failure, Animal>> addAnimal(Animal animal);
  Future<Either<Failure, Animal>> updateAnimal(Animal animal);
  Future<Either<Failure, void>> deleteAnimal(String id);
}
