import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/utils/guard.dart';
import 'package:farm_tracker/features/farm/data/datasources/analysis_remote_data_source.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';

/// Online-only (there is no local analytics mirror — RULES §7 keeps the
/// aggregates server-side). Thin per RULES §2: `guard()` owns the
/// exception → Failure mapping.
class AnalysisRepositoryImpl implements AnalysisRepository {
  AnalysisRepositoryImpl({required this.remoteDataSource});
  final AnalysisRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, FarmDetailedCost>> getTotalCostsBySeason(
    AnalyticsScope scope,
  ) => guard(() => remoteDataSource.getTotalCostsBySeason(scope));

  @override
  Future<Either<Failure, List<CostBreakdown>>> getCostBreakdownByInputType(
    AnalyticsScope scope,
  ) => guard(() async {
    final models = await remoteDataSource.getCostBreakdownByInputType(scope);
    return models
        .map(
          (m) => CostBreakdown(
            category: m.category,
            type: m.type,
            origin: m.origin,
            originId: m.originId,
            originType: m.originType,
            totalCost: m.totalCost,
            percentage: m.percentage,
          ),
        )
        .toList();
  });

  @override
  Future<Either<Failure, List<MonthlySummary>>> getAnnualCostSummary(
    DateTime startDate,
    DateTime endDate,
    AnalyticsScope scope,
  ) => guard(
    () => remoteDataSource.getAnnualCostSummary(startDate, endDate, scope),
  );
}
