import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/data/datasources/analysis_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/cost_breakdown_model.dart';
import 'package:farm_tracker/features/farm/data/models/farm_detailed_cost_model.dart';
import 'package:farm_tracker/features/farm/data/models/monthly_summary_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/analysis_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnalysisRemoteDataSource implements AnalysisRemoteDataSource {
  Exception? throwOnCostBreakdown;
  Exception? throwOnTotalCosts;

  @override
  Future<List<CostBreakdownModel>> getCostBreakdownByInputType() async {
    if (throwOnCostBreakdown != null) throw throwOnCostBreakdown!;
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
    if (throwOnTotalCosts != null) throw throwOnTotalCosts!;
    return const FarmDetailedCostModel(details: []);
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

  group('flag OFF error mapping (R2-02 net)', () {
    test(
      'getCostBreakdownByInputType: a NetworkException maps to '
      'NetworkFailure',
      () async {
        final dataSource = FakeAnalysisRemoteDataSource()
          ..throwOnCostBreakdown = NetworkException();
        final repository = AnalysisRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getCostBreakdownByInputType();

        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );

    test(
      'getCostBreakdownByInputType: a ServerException(msg) maps to '
      'ServerFailure(msg)',
      () async {
        final dataSource = FakeAnalysisRemoteDataSource()
          ..throwOnCostBreakdown = const ServerException('boom');
        final repository = AnalysisRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getCostBreakdownByInputType();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test(
      'getTotalCostsBySeason: a NetworkException maps to NetworkFailure',
      () async {
        final dataSource = FakeAnalysisRemoteDataSource()
          ..throwOnTotalCosts = NetworkException();
        final repository = AnalysisRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getTotalCostsBySeason();

        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );

    test(
      'getTotalCostsBySeason: a ServerException(msg) maps to '
      'ServerFailure(msg)',
      () async {
        final dataSource = FakeAnalysisRemoteDataSource()
          ..throwOnTotalCosts = const ServerException('boom');
        final repository = AnalysisRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getTotalCostsBySeason();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('a successful getTotalCostsBySeason maps to Right', () async {
      final dataSource = FakeAnalysisRemoteDataSource();
      final repository = AnalysisRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getTotalCostsBySeason();

      expect(result.isRight(), isTrue);
    });
  });
}
