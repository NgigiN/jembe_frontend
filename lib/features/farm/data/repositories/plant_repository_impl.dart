import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/plant.dart';
import '../../domain/repositories/plant_repository.dart';
import '../datasources/plant_remote_data_source.dart';
import '../models/plant_model.dart';

class PlantRepositoryImpl implements PlantRepository {
  final PlantRemoteDataSource remoteDataSource;

  PlantRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Plant>>> getPlants() async {
    try {
      final plants = await remoteDataSource.getPlants();
      return Right(plants);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Plant>> addPlant(Plant plant) async {
    try {
      final plantModel = PlantModel.create(
        userId: plant.userId,
        name: plant.name,
        variety: plant.variety,
      );

      final result = await remoteDataSource.addPlant(plantModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Plant>> updatePlant(Plant plant) async {
    try {
      final plantModel = PlantModel(
        id: plant.id,
        userId: plant.userId,
        name: plant.name,
        variety: plant.variety,
        createdAt: plant.createdAt,
        updatedAt: plant.updatedAt,
      );
      final result = await remoteDataSource.updatePlant(plantModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deletePlant(String id) async {
    try {
      await remoteDataSource.deletePlant(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}

