import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/total_costs_by_season.dart';
import '../../domain/entities/cost_breakdown.dart';
import '../../domain/entities/annual_cost_summary.dart';
import '../../domain/repositories/analysis_repository.dart';
import '../datasources/analysis_remote_data_source.dart';

class AnalysisRepositoryImpl implements AnalysisRepository {
  final AnalysisRemoteDataSource remoteDataSource;

  AnalysisRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<TotalCostsBySeason>>>
  getTotalCostsBySeason() async {
    try {
      final totalCostsModels = await remoteDataSource.getTotalCostsBySeason();
      final totalCosts = totalCostsModels
          .map(
            (model) => TotalCostsBySeason(
              seasonId: model.seasonId,
              seasonName: model.seasonName,
              startDate: model.startDate,
              cropName: model.cropName,
              landName: model.landName,
              farmName: model.farmName,
              totalCost: model.totalCost,
            ),
          )
          .toList();
      return Right(totalCosts);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<CostBreakdown>>>
  getCostBreakdownByInputType() async {
    try {
      final breakdownModels = await remoteDataSource
          .getCostBreakdownByInputType();
      final breakdowns = breakdownModels
          .map(
            (model) => CostBreakdown(
              seasonId: model.seasonId,
              seasonName: model.seasonName,
              cropName: model.cropName,
              landName: model.landName,
              inputType: model.inputType,
              farmName: model.farmName,
              inputCost: model.inputCost,
              percentage: model.percentage,
              category: model.category,
            ),
          )
          .toList();
      return Right(breakdowns);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AnnualCostSummary>>>
  getAnnualCostSummary() async {
    try {
      final summaryModels = await remoteDataSource.getAnnualCostSummary();
      final summaries = summaryModels
          .map(
            (model) => AnnualCostSummary(
              year: model.year,
              cropName: model.cropName,
              landName: model.landName,
              farmName: model.farmName,
              totalCost: model.totalCost,
            ),
          )
          .toList();
      return Right(summaries);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
