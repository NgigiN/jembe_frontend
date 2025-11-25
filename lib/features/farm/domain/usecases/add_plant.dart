import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/plant.dart';
import '../repositories/plant_repository.dart';

class AddPlant implements UseCase<Plant, AddPlantParams> {
  final PlantRepository repository;

  AddPlant(this.repository);

  @override
  Future<Either<Failure, Plant>> call(AddPlantParams params) async {
    return await repository.addPlant(params.plant);
  }
}

class AddPlantParams {
  final Plant plant;

  AddPlantParams({required this.plant});
}

