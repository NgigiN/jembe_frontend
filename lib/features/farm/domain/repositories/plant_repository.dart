import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';

abstract class PlantRepository {
  Future<Either<Failure, List<Plant>>> getPlants();
  Future<Either<Failure, Plant>> addPlant(Plant plant);
  Future<Either<Failure, Plant>> updatePlant(Plant plant);
  Future<Either<Failure, void>> deletePlant(String id);
}
