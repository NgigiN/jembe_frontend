import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/animal.dart';
import '../repositories/animal_repository.dart';

class AddAnimal implements UseCase<Animal, AddAnimalParams> {
  final AnimalRepository repository;

  AddAnimal(this.repository);

  @override
  Future<Either<Failure, Animal>> call(AddAnimalParams params) async {
    return await repository.addAnimal(params.animal);
  }
}

class AddAnimalParams {
  final Animal animal;

  AddAnimalParams({required this.animal});
}
