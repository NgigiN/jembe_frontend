import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/animal_type.dart';
import '../repositories/animal_type_repository.dart';

class AddAnimalType {
  final AnimalTypeRepository repository;

  AddAnimalType(this.repository);

  Future<Either<Failure, AnimalType>> call(String name, String? notes, String userId) async {
    return await repository.addAnimalType(name, notes, userId);
  }
}

