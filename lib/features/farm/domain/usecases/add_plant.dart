import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';

class AddPlant implements UseCase<Plant, AddPlantParams> {
  AddPlant(this.repository);
  final PlantRepository repository;

  @override
  Future<Either<Failure, Plant>> call(AddPlantParams params) async {
    return repository.addPlant(params.plant);
  }
}

class AddPlantParams {
  AddPlantParams({required this.plant});
  final Plant plant;
}
