import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/plant.dart';
import '../repositories/plant_repository.dart';

class UpdatePlant implements UseCase<Plant, UpdatePlantParams> {
  final PlantRepository repository;

  UpdatePlant(this.repository);

  @override
  Future<Either<Failure, Plant>> call(UpdatePlantParams params) async {
    return await repository.updatePlant(params.plant);
  }
}

class UpdatePlantParams {
  final Plant plant;

  UpdatePlantParams({required this.plant});
}

