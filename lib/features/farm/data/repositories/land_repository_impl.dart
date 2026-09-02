import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';

class LandRepositoryImpl implements LandRepository {
  LandRepositoryImpl({required this.remoteDataSource});
  final LandRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Land>>> getLands() async {
    try {
      final lands = await remoteDataSource.getLands();
      return Right(lands);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Land>> addLand(Land land) async {
    try {
      // Use the create factory method to convert Land entity to LandModel
      final landModel = LandModel.create(
        userId: land.userId,
        name: land.name,
        size: land.size,
        location: land.location,
        soilType: land.soilType,
        tenureType: land.tenureType,
      );

      final result = await remoteDataSource.addLand(landModel);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Land>> updateLand(Land land) async {
    try {
      // Convert Land entity to LandModel
      final landModel = LandModel(
        id: land.id,
        userId: land.userId,
        name: land.name,
        size: land.size,
        location: land.location,
        soilType: land.soilType,
        tenureType: land.tenureType,
        createdAt: land.createdAt,
        updatedAt: land.updatedAt,
      );

      final result = await remoteDataSource.updateLand(landModel);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteLand(String id) async {
    try {
      await remoteDataSource.deleteLand(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
