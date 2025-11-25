import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/animal_type_repository.dart';

class DeleteAnimalType {
  final AnimalTypeRepository repository;

  DeleteAnimalType(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteAnimalType(id);
  }
}

