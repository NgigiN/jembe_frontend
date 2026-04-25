import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';

class UpdatePlant implements UseCase<Plant, UpdatePlantParams> {
  UpdatePlant(this.repository);
  final PlantRepository repository;

  @override
  Future<Either<Failure, Plant>> call(UpdatePlantParams params) async {
    return repository.updatePlant(params.plant);
  }
}

class UpdatePlantParams {
  UpdatePlantParams({required this.plant});
  final Plant plant;
}
