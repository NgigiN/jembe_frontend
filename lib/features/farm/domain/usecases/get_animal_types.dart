import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/animal_type.dart';
import '../repositories/animal_type_repository.dart';

class GetAnimalTypes implements UseCase<List<AnimalType>, NoParams> {
  final AnimalTypeRepository repository;

  GetAnimalTypes(this.repository);

  @override
  Future<Either<Failure, List<AnimalType>>> call(NoParams params) async {
    return await repository.getAnimalTypes();
  }
}

