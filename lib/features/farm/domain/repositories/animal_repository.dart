import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/animal.dart';

abstract class AnimalRepository {
  Future<Either<Failure, List<Animal>>> getAnimals();
  Future<Either<Failure, Animal>> addAnimal(Animal animal);
  Future<Either<Failure, Animal>> updateAnimal(Animal animal);
  Future<Either<Failure, void>> deleteAnimal(String id);
}

