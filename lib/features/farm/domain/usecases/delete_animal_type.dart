import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_type_repository.dart';

class DeleteAnimalType {
  DeleteAnimalType(this.repository);
  final AnimalTypeRepository repository;

  Future<Either<Failure, void>> call(String id) async {
    return repository.deleteAnimalType(id);
  }
}
