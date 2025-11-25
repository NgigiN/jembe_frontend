import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/animal.dart';
import '../repositories/animal_repository.dart';

class GetAnimals implements UseCase<List<Animal>, NoParams> {
  final AnimalRepository repository;

  GetAnimals(this.repository);

  @override
  Future<Either<Failure, List<Animal>>> call(NoParams params) async {
    return await repository.getAnimals();
  }
}

