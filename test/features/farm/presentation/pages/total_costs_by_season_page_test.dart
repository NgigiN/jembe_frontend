import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analysis_page.dart';

class MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc {}

void main() {
  testWidgets(
    'TotalCostsBySeasonPage renders the cost list with no header container',
    (tester) async {
      final bloc = MockAnalysisBloc();
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
        ],
      );

      whenListen(
        bloc,
        Stream<AnalysisState>.value(
          TotalCostsBySeasonLoaded(detailedCosts),
        ),
        initialState: TotalCostsBySeasonLoaded(detailedCosts),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AnalysisBloc>.value(
            value: bloc,
            child: const TotalCostsBySeasonPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Long Rains 2026'), findsOneWidget);
      expect(find.text('Total Overall Farm Cost'), findsNothing);
      expect(find.byType(CustomScrollView), findsNothing);
    },
  );
}
