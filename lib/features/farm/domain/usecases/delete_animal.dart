import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';

class DeleteAnimal implements UseCase<void, DeleteAnimalParams> {
  DeleteAnimal(this.repository);
  final AnimalRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteAnimalParams params) async {
    return repository.deleteAnimal(params.id);
  }
}

class DeleteAnimalParams {
  DeleteAnimalParams({required this.id});
  final String id;
}
