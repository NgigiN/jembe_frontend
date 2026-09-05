import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analysis_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

void main() {
  testWidgets(
    'filters breakdown rows by the selected season, keeps farm-wide rows visible by default',
    (tester) async {
      final analysisBloc = MockAnalysisBloc();
      final seasonBloc = MockSeasonBloc();
      final herdBloc = MockHerdBloc();

      final season = Season(
        id: '1',
        userId: 'u1',
        name: 'Long Rains 2026',
        plantId: 'p1',
        landId: 'l1',
        startDate: DateTime(2026, 3),
        createdAt: DateTime(2026, 3),
        updatedAt: DateTime(2026, 3),
      );

      const seasonRow = CostBreakdown(
        category: 'Seeds',
        type: 'plant',
        origin: 'Long Rains 2026',
        originId: '1',
        originType: 'season',
        totalCost: 500,
        percentage: 60,
      );
      const farmWideRow = CostBreakdown(
        category: 'Fence',
        type: 'animal',
        origin: 'General',
        totalCost: 200,
        percentage: 40,
      );

      whenListen(
        analysisBloc,
        Stream<AnalysisState>.value(
          const AnalysisState(breakdowns: [seasonRow, farmWideRow]),
        ),
        initialState: const AnalysisState(
          breakdowns: [seasonRow, farmWideRow],
        ),
      );
      whenListen(
        seasonBloc,
        Stream<SeasonState>.value(SeasonLoaded(seasons: [season])),
        initialState: SeasonLoaded(seasons: [season]),
      );
      whenListen(
        herdBloc,
        Stream<HerdState>.value(const HerdLoaded([])),
        initialState: const HerdLoaded([]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AnalysisBloc>.value(value: analysisBloc),
              BlocProvider<SeasonBloc>.value(value: seasonBloc),
              BlocProvider<HerdBloc>.value(value: herdBloc),
            ],
            child: const CostBreakdownPage(),
          ),
        ),
      );
      await tester.pump();

      // Default view: both the season-backed row and the farm-wide row show.
      expect(find.text('Seeds'), findsOneWidget);
      expect(find.text('Fence'), findsOneWidget);

      // Filter down to just the season.
      await tester.tap(find.text('All Active Seasons/Herds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Long Rains 2026'));
      await tester.pumpAndSettle();

      expect(find.text('Seeds'), findsOneWidget);
      expect(find.text('Fence'), findsNothing);
    },
  );
}
