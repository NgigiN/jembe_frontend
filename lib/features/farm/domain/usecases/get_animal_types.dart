import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_type_repository.dart';

class GetAnimalTypes implements UseCase<List<AnimalType>, NoParams> {
  GetAnimalTypes(this.repository);
  final AnimalTypeRepository repository;

  @override
  Future<Either<Failure, List<AnimalType>>> call(NoParams params) async {
    return repository.getAnimalTypes();
  }
}
