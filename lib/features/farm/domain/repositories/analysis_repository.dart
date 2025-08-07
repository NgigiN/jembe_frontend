import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/total_costs_by_season.dart';
import '../entities/cost_breakdown.dart';
import '../entities/annual_cost_summary.dart';

abstract class AnalysisRepository {
  Future<Either<Failure, List<TotalCostsBySeason>>> getTotalCostsBySeason();
  Future<Either<Failure, List<CostBreakdown>>> getCostBreakdownByInputType();
  Future<Either<Failure, List<AnnualCostSummary>>> getAnnualCostSummary();
}
