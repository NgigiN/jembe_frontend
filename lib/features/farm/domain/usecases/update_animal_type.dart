import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/animal_type.dart';
import '../repositories/animal_type_repository.dart';

class UpdateAnimalType {
  final AnimalTypeRepository repository;

  UpdateAnimalType(this.repository);

  Future<Either<Failure, AnimalType>> call(String id, String name, String? notes) async {
    return await repository.updateAnimalType(id, name, notes);
  }
}

