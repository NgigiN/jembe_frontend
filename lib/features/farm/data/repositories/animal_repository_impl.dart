import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/animal.dart';
import '../../domain/repositories/animal_repository.dart';
import '../datasources/animal_remote_data_source.dart';
import '../models/animal_model.dart';

class AnimalRepositoryImpl implements AnimalRepository {
  final AnimalRemoteDataSource remoteDataSource;

  AnimalRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Animal>>> getAnimals() async {
    try {
      final animals = await remoteDataSource.getAnimals();
      return Right(animals);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Animal>> addAnimal(Animal animal) async {
    try {
      final animalModel = AnimalModel.create(
        userId: animal.userId,
        name: animal.name,
        type: animal.type,
        number: animal.number,
      );

      final result = await remoteDataSource.addAnimal(animalModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Animal>> updateAnimal(Animal animal) async {
    try {
      final animalModel = AnimalModel(
        id: animal.id,
        userId: animal.userId,
        name: animal.name,
        type: animal.type,
        number: animal.number,
        createdAt: animal.createdAt,
        updatedAt: animal.updatedAt,
      );
      final result = await remoteDataSource.updateAnimal(animalModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAnimal(String id) async {
    try {
      await remoteDataSource.deleteAnimal(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}

