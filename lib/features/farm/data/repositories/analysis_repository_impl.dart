import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/data/datasources/analysis_remote_data_source.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';

class AnalysisRepositoryImpl implements AnalysisRepository {

  AnalysisRepositoryImpl({required this.remoteDataSource});
  final AnalysisRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, FarmDetailedCost>> getTotalCostsBySeason() async {
    try {
      final model = await remoteDataSource.getTotalCostsBySeason();
      return Right(model);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<CostBreakdown>>> getCostBreakdownByInputType() async {
    try {
      final breakdownModels = await remoteDataSource.getCostBreakdownByInputType();
      final breakdowns =
          breakdownModels
              .map(
                (model) => CostBreakdown(
                  category: model.category,
                  type: model.type,
                  origin: model.origin,
                  originId: model.originId,
                  originType: model.originType,
                  totalCost: model.totalCost,
                  percentage: model.percentage,
                ),
              )
              .toList();
      return Right(breakdowns);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<MonthlySummary>>> getAnnualCostSummary(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final summaryModels = await remoteDataSource.getAnnualCostSummary(
        startDate,
        endDate,
      );
      return Right(summaryModels);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
