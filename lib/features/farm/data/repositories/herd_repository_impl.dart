import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';

class HerdRepositoryImpl implements HerdRepository {
  HerdRepositoryImpl({required this.remoteDataSource});
  final HerdRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Herd>>> getHerds() async {
    try {
      final herds = await remoteDataSource.getHerds();
      return Right(herds);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Herd>> addHerd(
    String name,
    String animalTypeId,
    String location,
    String userId,
    int initialHeadCount,
  ) async {
    try {
      final herdModel = HerdModel.create(
        userId: userId,
        name: name,
        animalTypeId: animalTypeId,
        location: location,
        initialHeadCount: initialHeadCount,
      );
      final result = await remoteDataSource.addHerd(herdModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Herd>> updateHerd(
    String id,
    String name,
    String animalTypeId,
    String location,
    int initialHeadCount,
  ) async {
    try {
      final herdModel = await remoteDataSource.getHerds();
      final existingHerd = herdModel.firstWhere((h) => h.id == id);
      final updatedModel = HerdModel(
        id: existingHerd.id,
        userId: existingHerd.userId,
        name: name,
        animalTypeId: animalTypeId,
        location: location,
        initialHeadCount: initialHeadCount,
        currentHeadCount: existingHerd.currentHeadCount,
        createdAt: existingHerd.createdAt,
        updatedAt: DateTime.now(),
      );
      final result = await remoteDataSource.updateHerd(updatedModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteHerd(String id) async {
    try {
      await remoteDataSource.deleteHerd(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
