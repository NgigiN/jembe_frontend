import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';

abstract class AnalysisRepository {
  Future<Either<Failure, FarmDetailedCost>> getTotalCostsBySeason();
  Future<Either<Failure, List<CostBreakdown>>> getCostBreakdownByInputType();
  Future<Either<Failure, List<MonthlySummary>>> getAnnualCostSummary();
}
