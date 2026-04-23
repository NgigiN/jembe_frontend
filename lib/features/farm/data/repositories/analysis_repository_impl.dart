import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/farm_detailed_cost.dart';
import '../../domain/entities/cost_breakdown.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/repositories/analysis_repository.dart';
import '../datasources/analysis_remote_data_source.dart';

class AnalysisRepositoryImpl implements AnalysisRepository {
  final AnalysisRemoteDataSource remoteDataSource;

  AnalysisRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, FarmDetailedCost>> getTotalCostsBySeason() async {
    try {
      final model = await remoteDataSource.getTotalCostsBySeason();
      return Right(model);
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
                  totalCost: model.totalCost,
                  percentage: model.percentage,
                ),
              )
              .toList();
      return Right(breakdowns);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<MonthlySummary>>> getAnnualCostSummary() async {
    try {
      final summaryModels = await remoteDataSource.getAnnualCostSummary();
      return Right(summaryModels);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
