import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';

class HarvestRepositoryImpl implements HarvestRepository {
  HarvestRepositoryImpl({required this.remoteDataSource});
  final HarvestRemoteDataSource remoteDataSource;

  HarvestModel _toModel(Harvest harvest) {
    return HarvestModel(
      id: harvest.id,
      seasonId: harvest.seasonId,
      quantity: harvest.quantity,
      unit: harvest.unit,
      date: harvest.date,
      notes: harvest.notes,
      revenueId: harvest.revenueId,
      createdAt: harvest.createdAt,
      updatedAt: harvest.updatedAt,
    );
  }

  @override
  Future<Either<Failure, List<Harvest>>> getHarvests({String? seasonId}) async {
    try {
      final harvests = await remoteDataSource.getHarvests(seasonId: seasonId);
      return Right(harvests);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Harvest>> addHarvest(Harvest harvest) async {
    try {
      final result = await remoteDataSource.addHarvest(_toModel(harvest));
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Harvest>> updateHarvest(Harvest harvest) async {
    try {
      final result = await remoteDataSource.updateHarvest(_toModel(harvest));
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteHarvest(String id) async {
    try {
      await remoteDataSource.deleteHarvest(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}