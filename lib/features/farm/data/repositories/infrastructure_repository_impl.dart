import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/infrastructure_model.dart';

class InfrastructureRepositoryImpl implements InfrastructureRepository {
  InfrastructureRepositoryImpl({required this.remoteDataSource});
  final InfrastructureRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Infrastructure>>> getInfrastructures() async {
    try {
      final list = await remoteDataSource.getInfrastructures();
      return Right(list);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Infrastructure>> addInfrastructure(
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String userId,
    String? notes,
  ) async {
    try {
      final model = InfrastructureModel.create(
        userId: userId,
        type: type,
        name: name,
        location: location,
        cost: cost,
        date: date,
        notes: notes,
      );
      final result = await remoteDataSource.addInfrastructure(model);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Infrastructure>> updateInfrastructure(
    String id,
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String? notes,
  ) async {
    try {
      final items = await remoteDataSource.getInfrastructures();
      final existing = items.firstWhere((item) => item.id == id);
      final updatedModel = InfrastructureModel(
        id: existing.id,
        userId: existing.userId,
        type: type,
        name: name,
        location: location,
        cost: cost,
        date: date,
        notes: notes ?? '',
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      final result = await remoteDataSource.updateInfrastructure(updatedModel);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInfrastructure(String id) async {
    try {
      await remoteDataSource.deleteInfrastructure(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
