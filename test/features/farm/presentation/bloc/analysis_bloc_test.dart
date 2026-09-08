import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every call's scope and answers from per-scope maps, so tests can
/// assert exactly which scopes were fetched and how many times.
class FakeAnalysisRepository implements AnalysisRepository {
  final costsBy = <AnalyticsScope, Either<Failure, FarmDetailedCost>>{};
  final breakdownBy = <AnalyticsScope, Either<Failure, List<CostBreakdown>>>{};
  final annualBy = <AnalyticsScope, Either<Failure, List<MonthlySummary>>>{};
  final costsCalls = <AnalyticsScope>[];
  final breakdownCalls = <AnalyticsScope>[];
  final annualCalls = <AnalyticsScope>[];

  /// When set, total-costs calls wait on it (simulates a slow reply).
  Completer<void>? gate;

  @override
  Future<Either<Failure, FarmDetailedCost>> getTotalCostsBySeason(
    AnalyticsScope scope,
  ) async {
    costsCalls.add(scope);
    final g = gate;
    if (g != null) await g.future;
    return costsBy[scope] ?? const Left(ServerFailure('not stubbed'));
  }

  @override
  Future<Either<Failure, List<CostBreakdown>>> getCostBreakdownByInputType(
    AnalyticsScope scope,
  ) async {
    breakdownCalls.add(scope);
    return breakdownBy[scope] ?? const Left(ServerFailure('not stubbed'));
  }

  @override
  Future<Either<Failure, List<MonthlySummary>>> getAnnualCostSummary(
    DateTime startDate,
    DateTime endDate,
    AnalyticsScope scope,
  ) async {
    annualCalls.add(scope);
    return annualBy[scope] ?? const Left(ServerFailure('not stubbed'));
  }
}

FarmDetailedCost _costs(String name) => FarmDetailedCost(
  details: [
    CostDetail(
      type: 'plant',
      id: 1,
      name: name,
      category: 'Maize',
      location: 'A',
      startDate: DateTime(2026, 3),
      inputCost: 1,
      activityCost: 1,
      totalCost: 2,
    ),
  ],
);
const _rows = [
  CostBreakdown(
    category: 'Seeds',
    type: 'plant',
    origin: 'S',
    totalCost: 5,
    percentage: 100,
  ),
];
const _all = AnalyticsScope.all();
const _land = AnalyticsScope.land('l1');

void main() {
  late FakeAnalysisRepository repo;
  late AnalysisBloc bloc;

  setUp(() {
    repo = FakeAnalysisRepository()
      ..costsBy[_all] = Right(_costs('all'))
      ..costsBy[_land] = Right(_costs('land'))
      ..breakdownBy[_all] = const Right(_rows)
      ..breakdownBy[_land] = const Right(_rows);
    bloc = AnalysisBloc(repository: repo);
  });
  tearDown(() => bloc.close());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('loading one slice never evicts another (F1-07 kept)', () async {
    bloc.add(const LoadTotalCostsBySeason());
    await settle();
    bloc.add(const LoadCostBreakdown());
    await settle();
    expect(bloc.state.detailedCosts.data, isNotNull);
    expect(bloc.state.breakdowns.data, isNotNull);
  });

  test('a slice error is isolated to that slice', () async {
    repo.breakdownBy[_all] = const Left(ServerFailure('boom'));
    bloc.add(const LoadTotalCostsBySeason());
    await settle();
    bloc.add(const LoadCostBreakdown());
    await settle();
    expect(bloc.state.detailedCosts.error, isNull);
    expect(bloc.state.detailedCosts.data, isNotNull);
    expect(bloc.state.breakdowns.error, 'boom');
    expect(bloc.state.breakdowns.data, isNull);
  });

  test(
    'scope change reloads ONLY the slices that hold data, with the new scope',
    () async {
      bloc.add(const LoadTotalCostsBySeason());
      await settle();
      bloc.add(const AnalysisScopeChanged(_land));
      await settle();
      expect(bloc.state.scope, _land);
      expect(repo.costsCalls, [_all, _land]);
      expect(
        repo.breakdownCalls,
        isEmpty,
        reason: 'breakdown was never loaded',
      );
      expect(repo.annualCalls, isEmpty);
      expect(bloc.state.detailedCosts.data!.details.single.name, 'land');
      expect(bloc.state.detailedCosts.loadedFor, _land);
    },
  );

  test(
    're-tapping a cached scope serves the cache first, then refreshes (SWR)',
    () async {
      bloc.add(const LoadTotalCostsBySeason());
      await settle();
      bloc.add(const AnalysisScopeChanged(_land));
      await settle();
      repo.costsBy[_all] = Right(_costs('all-v2'));
      final emissions = <AnalysisState>[];
      final sub = bloc.stream.listen(emissions.add);
      bloc.add(const AnalysisScopeChanged(_all));
      await settle();
      await sub.cancel();
      final names = emissions
          .where((s) => s.detailedCosts.data != null)
          .map((s) => s.detailedCosts.data!.details.single.name)
          .toList();
      expect(names.first, 'all', reason: 'cached value shown immediately');
      expect(names.last, 'all-v2', reason: 'then the fresh value');
      expect(
        emissions.any(
          (s) => s.detailedCosts.isLoading && s.detailedCosts.data == null,
        ),
        isFalse,
        reason: 'never a data-less spinner once cached',
      );
      expect(repo.costsCalls.where((s) => s == _all).length, 2);
    },
  );

  test(
    'forceRefresh bypasses the cache: emits loading with old data kept',
    () async {
      bloc.add(const LoadTotalCostsBySeason());
      await settle();
      final emissions = <AnalysisState>[];
      final sub = bloc.stream.listen(emissions.add);
      bloc.add(const LoadTotalCostsBySeason(forceRefresh: true));
      await settle();
      await sub.cancel();
      expect(emissions.first.detailedCosts.isLoading, isTrue);
      expect(
        emissions.first.detailedCosts.data,
        isNotNull,
        reason: 'rule 14: no flicker to empty',
      );
      expect(repo.costsCalls.length, 2);
    },
  );

  test('a response for a scope that is no longer current is dropped', () async {
    final gate = Completer<void>();
    repo.gate = gate;
    bloc.add(const LoadTotalCostsBySeason()); // 'all' request, held open
    await settle();
    repo.gate = null; // later calls are not gated
    bloc.add(const AnalysisScopeChanged(_land)); // no data yet → no reload
    await settle();
    gate.complete(); // the stale 'all' reply now arrives
    await settle();
    expect(bloc.state.scope, _land);
    expect(
      bloc.state.detailedCosts.data,
      isNull,
      reason: "the 'all' result must not land while the scope is 'land'",
    );
    expect(repo.costsCalls, [_all]);
  });

  test(
    'annual summary remembers its window and reloads it on scope change',
    () async {
      repo.annualBy[_all] = const Right(<MonthlySummary>[]);
      repo.annualBy[_land] = const Right(<MonthlySummary>[]);
      bloc.add(LoadAnnualCostSummary(DateTime(2026), DateTime(2027)));
      await settle();
      bloc.add(const AnalysisScopeChanged(_land));
      await settle();
      expect(repo.annualCalls, [_all, _land]);
      expect(bloc.state.summaries.data, isNotNull);
    },
  );
}
