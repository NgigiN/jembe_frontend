import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';

abstract class AnalysisRepository {
  Future<Either<Failure, FarmDetailedCost>> getTotalCostsBySeason(
    AnalyticsScope scope,
  );
  Future<Either<Failure, List<CostBreakdown>>> getCostBreakdownByInputType(
    AnalyticsScope scope,
  );
  Future<Either<Failure, List<MonthlySummary>>> getAnnualCostSummary(
    DateTime startDate,
    DateTime endDate,
    AnalyticsScope scope,
  );
}
