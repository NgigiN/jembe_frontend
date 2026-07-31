import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analysis_page.dart';

class MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

void main() {
  testWidgets(
    'defaults to Active-only and lets the farmer filter to one season',
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
        startDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );
      final closedHerd = Herd(
        id: '2',
        userId: 'u1',
        name: 'Broiler Batch 1',
        animalTypeId: 'a1',
        location: 'Coop A',
        initialHeadCount: 100,
        currentHeadCount: 0,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 2, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 2, 1),
      );

      final detailedCosts = FarmDetailedCost(
        details: [
          CostDetail(
            type: 'plant',
            id: 1,
            name: 'Long Rains 2026',
            category: 'Maize',
            location: 'Field A',
            startDate: DateTime(2026, 3, 1),
            inputCost: 500,
            activityCost: 200,
            totalCost: 700,
          ),
          CostDetail(
            type: 'animal',
            id: 2,
            name: 'Broiler Batch 1',
            category: 'Broilers',
            location: 'Coop A',
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2025, 2, 1),
            inputCost: 300,
            activityCost: 100,
            totalCost: 400,
          ),
        ],
      );

      whenListen(
        analysisBloc,
        Stream<AnalysisState>.value(TotalCostsBySeasonLoaded(detailedCosts)),
        initialState: TotalCostsBySeasonLoaded(detailedCosts),
      );
      whenListen(
        seasonBloc,
        Stream<SeasonState>.value(SeasonLoaded(seasons: [season])),
        initialState: SeasonLoaded(seasons: [season]),
      );
      whenListen(
        herdBloc,
        Stream<HerdState>.value(HerdLoaded([closedHerd])),
        initialState: HerdLoaded([closedHerd]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AnalysisBloc>.value(value: analysisBloc),
              BlocProvider<SeasonBloc>.value(value: seasonBloc),
              BlocProvider<HerdBloc>.value(value: herdBloc),
            ],
            child: const TotalCostsBySeasonPage(),
          ),
        ),
      );
      await tester.pump();

      // Default "All Active" hides the closed broiler batch.
      expect(find.text('Long Rains 2026'), findsOneWidget);
      expect(find.text('Broiler Batch 1'), findsNothing);

      // Opening the picker and selecting the closed herd (from Completed)
      // shows only that herd's row.
      await tester.tap(find.text('All Active Seasons/Herds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('COMPLETED (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Broiler Batch 1').last);
      await tester.pumpAndSettle();

      expect(find.text('Long Rains 2026'), findsNothing);
      // Appears twice: once as the picker button's label, once as the card title.
      expect(find.text('Broiler Batch 1'), findsNWidgets(2));
    },
  );
}
