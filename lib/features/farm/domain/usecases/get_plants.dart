import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';

class GetPlants implements UseCase<List<Plant>, NoParams> {
  GetPlants(this.repository);
  final PlantRepository repository;

  @override
  Future<Either<Failure, List<Plant>>> call(NoParams params) async {
    return repository.getPlants();
  }
}
