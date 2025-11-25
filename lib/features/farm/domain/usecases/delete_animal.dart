import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/animal_repository.dart';

class DeleteAnimal implements UseCase<void, DeleteAnimalParams> {
  final AnimalRepository repository;

  DeleteAnimal(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteAnimalParams params) async {
    return await repository.deleteAnimal(params.id);
  }
}

class DeleteAnimalParams {
  final String id;

  DeleteAnimalParams({required this.id});
}

