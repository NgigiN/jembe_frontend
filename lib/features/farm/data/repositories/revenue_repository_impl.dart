import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';

class RevenueRepositoryImpl implements RevenueRepository {
  RevenueRepositoryImpl({required this.remoteDataSource});
  final RevenueRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Revenue>>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final revenues = await remoteDataSource.getRevenues(
        source: source,
        startDate: startDate,
        endDate: endDate,
      );
      return Right(revenues);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Revenue>> getRevenueById(String id) async {
    try {
      final revenue = await remoteDataSource.getRevenueById(id);
      return Right(revenue);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Revenue>> addRevenue({
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required DateTime date,
    double? total,
    String? notes,
  }) async {
    try {
      final revenueModel = RevenueModel.create(
        source: source,
        sourceId: sourceId,
        type: type,
        quantity: quantity,
        unitPrice: unitPrice,
        total: total,
        date: date,
        notes: notes,
      );
      final revenue = await remoteDataSource.addRevenue(revenueModel);
      return Right(revenue);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Revenue>> updateRevenue({
    required String id,
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required double total,
    required DateTime date,
    String? notes,
  }) async {
    try {
      final revenueModel = RevenueModel(
        id: id,
        userId: '',
        source: source,
        sourceId: sourceId,
        type: type,
        quantity: quantity,
        unitPrice: unitPrice,
        total: total,
        date: date,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final revenue = await remoteDataSource.updateRevenue(revenueModel);
      return Right(revenue);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRevenue(String id) async {
    try {
      await remoteDataSource.deleteRevenue(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
