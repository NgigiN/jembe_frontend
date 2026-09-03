import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_annual_cost_summary.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_total_costs_by_season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnalysisRepository implements AnalysisRepository {
  FakeAnalysisRepository({
    this.totalCostsResult,
    this.breakdownResult,
    this.annualSummaryResult,
  });

  Either<Failure, FarmDetailedCost>? totalCostsResult;
  Either<Failure, List<CostBreakdown>>? breakdownResult;
  Either<Failure, List<MonthlySummary>>? annualSummaryResult;

  @override
  Future<Either<Failure, FarmDetailedCost>> getTotalCostsBySeason() async {
    return totalCostsResult ?? const Left(ServerFailure('not stubbed'));
  }

  @override
  Future<Either<Failure, List<CostBreakdown>>>
      getCostBreakdownByInputType() async {
    return breakdownResult ?? const Left(ServerFailure('not stubbed'));
  }

  @override
  Future<Either<Failure, List<MonthlySummary>>> getAnnualCostSummary(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return annualSummaryResult ?? const Left(ServerFailure('not stubbed'));
  }
}

void main() {
  group('AnalysisBloc', () {
    test(
      'keeps previously loaded datasets when a different dataset loads (no eviction)',
      () async {
        final detailedCosts = FarmDetailedCost(
          details: [
            CostDetail(
              type: 'plant',
              id: 1,
              name: 'Long Rains 2026',
              category: 'Maize',
              location: 'Field A',
              startDate: DateTime(2026, 3),
              inputCost: 500,
              activityCost: 200,
              totalCost: 700,
            ),
          ],
        );
        const breakdowns = [
          CostBreakdown(
            category: 'Seeds',
            type: 'plant',
            origin: 'Long Rains 2026',
            originId: '1',
            originType: 'season',
            totalCost: 500,
            percentage: 60,
          ),
        ];

        final repository = FakeAnalysisRepository(
          totalCostsResult: Right(detailedCosts),
          breakdownResult: const Right(breakdowns),
        );

        final bloc = AnalysisBloc(
          getTotalCostsBySeason: GetTotalCostsBySeason(repository),
          getCostBreakdown: GetCostBreakdown(repository),
          getAnnualCostSummary: GetAnnualCostSummary(repository),
        );
        addTearDown(bloc.close);

        bloc.add(LoadTotalCostsBySeason());
        await bloc.stream.firstWhere((s) => s.detailedCosts != null);

        expect(bloc.state.detailedCosts, isNotNull);

        bloc.add(LoadCostBreakdown());
        await bloc.stream.firstWhere((s) => s.breakdowns != null);

        // Loading the breakdown must NOT evict the previously loaded
        // detailed costs — both datasets coexist in state.
        expect(bloc.state.detailedCosts, isNotNull);
        expect(bloc.state.breakdowns, isNotNull);
      },
    );
  });
}
