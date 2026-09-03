import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';

class PlantRepositoryImpl implements PlantRepository {
  PlantRepositoryImpl({required this.remoteDataSource});
  final PlantRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Plant>>> getPlants() async {
    try {
      final plants = await remoteDataSource.getPlants();
      return Right(plants);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
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
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
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
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deletePlant(String id) async {
    try {
      await remoteDataSource.deletePlant(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
