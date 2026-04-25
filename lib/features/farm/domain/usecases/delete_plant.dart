import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';

class DeletePlant implements UseCase<void, DeletePlantParams> {
  DeletePlant(this.repository);
  final PlantRepository repository;

  @override
  Future<Either<Failure, void>> call(DeletePlantParams params) async {
    return repository.deletePlant(params.id);
  }
}

class DeletePlantParams {
  DeletePlantParams({required this.id});
  final String id;
}
