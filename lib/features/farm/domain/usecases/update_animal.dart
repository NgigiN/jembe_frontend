import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';

class UpdateAnimal implements UseCase<Animal, UpdateAnimalParams> {
  UpdateAnimal(this.repository);
  final AnimalRepository repository;

  @override
  Future<Either<Failure, Animal>> call(UpdateAnimalParams params) async {
    return repository.updateAnimal(params.animal);
  }
}

class UpdateAnimalParams {
  UpdateAnimalParams({required this.animal});
  final Animal animal;
}
