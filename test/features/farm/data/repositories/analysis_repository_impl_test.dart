import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/farm/data/datasources/analysis_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/cost_breakdown_model.dart';
import 'package:farm_tracker/features/farm/data/models/farm_detailed_cost_model.dart';
import 'package:farm_tracker/features/farm/data/models/monthly_summary_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/analysis_repository_impl.dart';

class FakeAnalysisRemoteDataSource implements AnalysisRemoteDataSource {
  @override
  Future<List<CostBreakdownModel>> getCostBreakdownByInputType() async {
    return const [
      CostBreakdownModel(
        category: 'Seeds',
        type: 'plant',
        origin: 'Long Rains 2026',
        originId: '5',
        originType: 'season',
        totalCost: 500,
        percentage: 60,
      ),
    ];
  }

  @override
  Future<FarmDetailedCostModel> getTotalCostsBySeason() async {
    throw UnimplementedError();
  }

  @override
  Future<List<MonthlySummaryModel>> getAnnualCostSummary(
    DateTime startDate,
    DateTime endDate,
  ) async {
    throw UnimplementedError();
  }
}

void main() {
  test(
    'getCostBreakdownByInputType carries originId/originType from model to entity',
    () async {
      final repository = AnalysisRepositoryImpl(
        remoteDataSource: FakeAnalysisRemoteDataSource(),
      );

      final result = await repository.getCostBreakdownByInputType();

      final breakdowns = result.getOrElse(() => []);
      expect(breakdowns, hasLength(1));
      expect(breakdowns.first.originId, '5');
      expect(breakdowns.first.originType, 'season');
    },
  );
}
