import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';

class InputRepositoryImpl implements InputRepository {
  InputRepositoryImpl({required this.remoteDataSource});
  final InputRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Input>>> getInputs({String? sourceType}) async {
    try {
      final inputs = await remoteDataSource.getInputs(sourceType: sourceType);
      return Right(inputs);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Input>> addInput(Input input) async {
    try {
      // Convert Input entity to InputModel
      final inputModel = InputModel(
        id: input.id,
        sourceType: input.sourceType,
        sourceId: input.sourceId,
        animalId: input.animalId,
        type: input.type,
        quantity: input.quantity,
        cost: input.cost,
        date: input.date,
        createdAt: input.createdAt,
        updatedAt: input.updatedAt,
      );

      final result = await remoteDataSource.addInput(inputModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Input>> updateInput(Input input) async {
    try {
      // Convert Input entity to InputModel
      final inputModel = InputModel(
        id: input.id,
        sourceType: input.sourceType,
        sourceId: input.sourceId,
        animalId: input.animalId,
        type: input.type,
        quantity: input.quantity,
        cost: input.cost,
        date: input.date,
        createdAt: input.createdAt,
        updatedAt: input.updatedAt,
      );

      final result = await remoteDataSource.updateInput(inputModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInput(String id) async {
    try {
      await remoteDataSource.deleteInput(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
