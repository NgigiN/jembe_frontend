import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/plant_repository.dart';

class DeletePlant implements UseCase<void, DeletePlantParams> {
  final PlantRepository repository;

  DeletePlant(this.repository);

  @override
  Future<Either<Failure, void>> call(DeletePlantParams params) async {
    return await repository.deletePlant(params.id);
  }
}

class DeletePlantParams {
  final String id;

  DeletePlantParams({required this.id});
}

