import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/total_costs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

CostDetail _detail(String name, {required String type, DateTime? end}) =>
    CostDetail(
      type: type,
      id: name.hashCode,
      name: name,
      category: 'c',
      location: 'l',
      startDate: DateTime(2025),
      endDate: end,
      inputCost: 1,
      activityCost: 1,
      totalCost: 2,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const LoadTotalCostsBySeason());
    registerFallbackValue(GetLandsEvent());
    registerFallbackValue(GetHerdsEvent());
  });

  late MockAnalysisBloc analysis;
  late MockLandBloc lands;
  late MockHerdBloc herds;

  Widget wrap() => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AnalysisBloc>.value(value: analysis),
        BlocProvider<LandBloc>.value(value: lands),
        BlocProvider<HerdBloc>.value(value: herds),
      ],
      child: const TotalCostsBySeasonPage(),
    ),
  );

  setUp(() {
    analysis = MockAnalysisBloc();
    lands = MockLandBloc();
    herds = MockHerdBloc();
    final land = Land(
      id: 'l1',
      userId: 'u',
      name: 'Shamba A',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    whenListen(
      lands,
      Stream<LandState>.value(LandLoaded(lands: [land])),
      initialState: LandLoaded(lands: [land]),
    );
    whenListen(
      herds,
      Stream<HerdState>.value(const HerdLoaded([])),
      initialState: const HerdLoaded([]),
    );
  });

  testWidgets(
    'loads on mount, renders chips, and groups rows into Active / Completed',
    (tester) async {
      final state = AnalysisState(
        detailedCosts: AnalysisSlice(
          data: FarmDetailedCost(
            details: [
              _detail('Long Rains 2026', type: 'plant'),
              _detail('Broilers 2025', type: 'animal', end: DateTime(2025, 2)),
            ],
          ),
          loadedFor: const AnalyticsScope.all(),
        ),
      );
      whenListen(
        analysis,
        Stream<AnalysisState>.value(state),
        initialState: state,
      );

      await tester.pumpWidget(wrap());
      await tester.pump();

      verify(
        () => analysis.add(any(that: isA<LoadTotalCostsBySeason>())),
      ).called(1);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);
      expect(find.text('Long Rains 2026'), findsOneWidget);
      expect(find.text('Broilers 2025'), findsOneWidget);
    },
  );

  testWidgets('tapping Plants then a land dispatches AnalysisScopeChanged', (
    tester,
  ) async {
    const plants = AnalyticsScope.source(ScopeSource.plant);
    const s0 = AnalysisState(
      detailedCosts: AnalysisSlice(data: FarmDetailedCost(details: [])),
    );
    whenListen(
      analysis,
      Stream<AnalysisState>.fromIterable([s0, s0.copyWith(scope: plants)]),
      initialState: s0,
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.tap(find.text('Plants'));
    verify(() => analysis.add(const AnalysisScopeChanged(plants))).called(1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shamba A'));
    verify(
      () => analysis.add(const AnalysisScopeChanged(AnalyticsScope.land('l1'))),
    ).called(1);
  });

  testWidgets('error with no data shows the kit error view with retry', (
    tester,
  ) async {
    const state = AnalysisState(detailedCosts: AnalysisSlice(error: 'boom'));
    whenListen(
      analysis,
      Stream<AnalysisState>.value(state),
      initialState: state,
    );
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(find.text('boom'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    verify(
      () => analysis.add(
        any(
          that: isA<LoadTotalCostsBySeason>().having(
            (e) => e.forceRefresh,
            'forceRefresh',
            isTrue,
          ),
        ),
      ),
    ).called(1);
  });
}
