import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/farm_detailed_cost.dart';
import '../entities/cost_breakdown.dart';
import '../entities/monthly_summary.dart';

abstract class AnalysisRepository {
  Future<Either<Failure, FarmDetailedCost>> getTotalCostsBySeason();
  Future<Either<Failure, List<CostBreakdown>>> getCostBreakdownByInputType();
  Future<Either<Failure, List<MonthlySummary>>> getAnnualCostSummary();
}
