import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_type_repository.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';

class AnimalTypeRepositoryImpl implements AnimalTypeRepository {
  AnimalTypeRepositoryImpl({required this.remoteDataSource});
  final AnimalTypeRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<AnimalType>>> getAnimalTypes() async {
    try {
      final animalTypes = await remoteDataSource.getAnimalTypes();
      return Right(animalTypes);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e}'));
    }
  }

  @override
  Future<Either<Failure, AnimalType>> getAnimalType(String id) async {
    try {
      final animalType = await remoteDataSource.getAnimalType(id);
      return Right(animalType);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e}'));
    }
  }

  @override
  Future<Either<Failure, AnimalType>> addAnimalType(
    String name,
    String? notes,
    String userId,
  ) async {
    try {
      final animalTypeModel = AnimalTypeModel.create(
        userId: userId,
        name: name,
        notes: notes,
      );
      final result = await remoteDataSource.addAnimalType(animalTypeModel);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e}'));
    }
  }

  @override
  Future<Either<Failure, AnimalType>> updateAnimalType(
    String id,
    String name,
    String? notes,
  ) async {
    try {
      final animalTypeModel = await remoteDataSource.getAnimalType(id);
      final updatedModel = AnimalTypeModel(
        id: animalTypeModel.id,
        userId: animalTypeModel.userId,
        name: name,
        notes: notes,
        createdAt: animalTypeModel.createdAt,
        updatedAt: DateTime.now(),
      );
      final result = await remoteDataSource.updateAnimalType(updatedModel);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAnimalType(String id) async {
    try {
      await remoteDataSource.deleteAnimalType(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e}'));
    }
  }
}
