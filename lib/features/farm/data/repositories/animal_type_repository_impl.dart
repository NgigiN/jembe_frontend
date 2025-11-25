import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/animal_type.dart';
import '../../domain/repositories/animal_type_repository.dart';
import '../datasources/animal_type_remote_data_source.dart';
import '../models/animal_type_model.dart';

class AnimalTypeRepositoryImpl implements AnimalTypeRepository {
  final AnimalTypeRemoteDataSource remoteDataSource;

  AnimalTypeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<AnimalType>>> getAnimalTypes() async {
    try {
      final animalTypes = await remoteDataSource.getAnimalTypes();
      return Right(animalTypes);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AnimalType>> getAnimalType(String id) async {
    try {
      final animalType = await remoteDataSource.getAnimalType(id);
      return Right(animalType);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AnimalType>> addAnimalType(String name, String? notes, String userId) async {
    try {
      final animalTypeModel = AnimalTypeModel.create(
        userId: userId,
        name: name,
        notes: notes,
      );
      final result = await remoteDataSource.addAnimalType(animalTypeModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AnimalType>> updateAnimalType(String id, String name, String? notes) async {
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAnimalType(String id) async {
    try {
      await remoteDataSource.deleteAnimalType(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }
}

