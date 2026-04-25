import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';

class AddAnimal implements UseCase<Animal, AddAnimalParams> {
  AddAnimal(this.repository);
  final AnimalRepository repository;

  @override
  Future<Either<Failure, Animal>> call(AddAnimalParams params) async {
    return repository.addAnimal(params.animal);
  }
}

class AddAnimalParams {
  AddAnimalParams({required this.animal});
  final Animal animal;
}
