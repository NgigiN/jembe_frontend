import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/animal.dart';
import '../repositories/animal_repository.dart';

class UpdateAnimal implements UseCase<Animal, UpdateAnimalParams> {
  final AnimalRepository repository;

  UpdateAnimal(this.repository);

  @override
  Future<Either<Failure, Animal>> call(UpdateAnimalParams params) async {
    return await repository.updateAnimal(params.animal);
  }
}

class UpdateAnimalParams {
  final Animal animal;

  UpdateAnimalParams({required this.animal});
}

