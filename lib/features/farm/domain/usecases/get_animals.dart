import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';

class GetAnimals implements UseCase<List<Animal>, NoParams> {
  GetAnimals(this.repository);
  final AnimalRepository repository;

  @override
  Future<Either<Failure, List<Animal>>> call(NoParams params) async {
    return repository.getAnimals();
  }
}
