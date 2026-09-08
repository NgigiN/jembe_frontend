import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/cost_breakdown_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const LoadCostBreakdown());
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
      child: const CostBreakdownPage(),
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
    'renders one expandable group per input type with the scoped total',
    (tester) async {
      const rows = [
        CostBreakdown(
          category: 'Seeds',
          type: 'plant',
          origin: 'Long Rains 2026',
          originId: '1',
          originType: 'season',
          totalCost: 500,
          percentage: 60,
        ),
        CostBreakdown(
          category: 'Seeds',
          type: 'plant',
          origin: 'Short Rains 2025',
          originId: '2',
          originType: 'season',
          totalCost: 300,
          percentage: 36,
        ),
        CostBreakdown(
          category: 'Fence',
          type: 'animal',
          origin: 'Fence',
          totalCost: 33.3,
          percentage: 4,
        ),
      ];
      const state = AnalysisState(
        breakdowns: AnalysisSlice(data: rows, loadedFor: AnalyticsScope.all()),
      );
      whenListen(
        analysis,
        Stream<AnalysisState>.value(state),
        initialState: state,
      );

      await tester.pumpWidget(wrap());
      await tester.pump();

      verify(() => analysis.add(any(that: isA<LoadCostBreakdown>()))).called(1);
      expect(find.text('Seeds'), findsOneWidget);
      expect(find.text('KES 800'), findsOneWidget);
      expect(find.text('96.0%'), findsOneWidget);
      expect(
        find.text('Long Rains 2026'),
        findsNothing,
        reason: 'origins collapsed by default',
      );
      await tester.tap(find.text('Seeds'));
      await tester.pumpAndSettle();
      expect(find.text('Long Rains 2026'), findsOneWidget);
      expect(find.text('Short Rains 2025'), findsOneWidget);
    },
  );

  testWidgets('tapping Animals dispatches AnalysisScopeChanged', (
    tester,
  ) async {
    const state = AnalysisState(
      breakdowns: AnalysisSlice(data: <CostBreakdown>[]),
    );
    whenListen(
      analysis,
      Stream<AnalysisState>.value(state),
      initialState: state,
    );
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.tap(find.text('Animals'));
    verify(
      () => analysis.add(
        const AnalysisScopeChanged(AnalyticsScope.source(ScopeSource.animal)),
      ),
    ).called(1);
  });
}
