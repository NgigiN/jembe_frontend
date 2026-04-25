import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_type_repository.dart';

class UpdateAnimalType {
  UpdateAnimalType(this.repository);
  final AnimalTypeRepository repository;

  Future<Either<Failure, AnimalType>> call(
    String id,
    String name,
    String? notes,
  ) async {
    return repository.updateAnimalType(id, name, notes);
  }
}
