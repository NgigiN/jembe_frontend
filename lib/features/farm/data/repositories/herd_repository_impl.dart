import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/herd.dart';
import '../../domain/repositories/herd_repository.dart';
import '../datasources/herd_remote_data_source.dart';
import '../models/herd_model.dart';

class HerdRepositoryImpl implements HerdRepository {
  final HerdRemoteDataSource remoteDataSource;

  HerdRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Herd>>> getHerds() async {
    try {
      final herds = await remoteDataSource.getHerds();
      return Right(herds);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Herd>> addHerd(String name, String animalTypeId, String location, String userId) async {
    try {
      final herdModel = HerdModel.create(
        userId: userId,
        name: name,
        animalTypeId: animalTypeId,
        location: location,
      );
      final result = await remoteDataSource.addHerd(herdModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Herd>> updateHerd(String id, String name, String animalTypeId, String location) async {
    try {
      final herdModel = await remoteDataSource.getHerds();
      final existingHerd = herdModel.firstWhere((h) => h.id == id);
      final updatedModel = HerdModel(
        id: existingHerd.id,
        userId: existingHerd.userId,
        name: name,
        animalTypeId: animalTypeId,
        location: location,
        createdAt: existingHerd.createdAt,
        updatedAt: DateTime.now(),
      );
      final result = await remoteDataSource.updateHerd(updatedModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
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
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }
}

