import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const LoadTotalCostsBySeason());
    registerFallbackValue(const LoadCostBreakdown());
    registerFallbackValue(LoadAnnualCostSummary(DateTime(2026), DateTime(2027)));
  });

  final detail = CostDetail(
    type: 'plant',
    id: 1,
    name: 'Maize Season 1',
    category: 'Crop',
    location: 'North Field',
    startDate: DateTime(2026),
    inputCost: 100,
    activityCost: 50,
    totalCost: 150,
  );

  final loaded = AnalysisState(
    detailedCosts: AnalysisSlice(data: FarmDetailedCost(details: [detail])),
  );

  testWidgets('renders a real field from the loaded state', (tester) async {
    final bloc = MockAnalysisBloc();
    whenListen(bloc, const Stream<AnalysisState>.empty(), initialState: loaded);

    await tester.pumpWidget(
      BlocProvider<AnalysisBloc>.value(
        value: bloc, child: const MaterialApp(home: WebReportsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maize Season 1'), findsOneWidget);
  });

  testWidgets('dispatches the analysis load events on init', (tester) async {
    final bloc = MockAnalysisBloc();
    whenListen(
      bloc, const Stream<AnalysisState>.empty(),
      initialState: const AnalysisState(),
    );

    await tester.pumpWidget(
      BlocProvider<AnalysisBloc>.value(
        value: bloc, child: const MaterialApp(home: WebReportsPage()),
      ),
    );
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<LoadTotalCostsBySeason>())),
    ).called(1);
    verify(() => bloc.add(any(that: isA<LoadCostBreakdown>()))).called(1);
    verify(
      () => bloc.add(any(that: isA<LoadAnnualCostSummary>())),
    ).called(1);
  });

  testWidgets('renders a monthly summary row from the loaded state', (
    tester,
  ) async {
    final bloc = MockAnalysisBloc();
    final withSummary = AnalysisState(
      detailedCosts: AnalysisSlice(data: FarmDetailedCost(details: [detail])),
      summaries: const AnalysisSlice(
        data: [
          MonthlySummary(
            month: 'Jan 2026',
            totalCosts: 200,
            totalRevenue: 500,
            profit: 300,
            breakdown: MonthlySummaryBreakdown(
              costs: MonthlyCostBreakdown(plant: 100, animal: 100, infrastructure: 0),
              revenue: MonthlyRevenueBreakdown(plant: 500, animal: 0),
            ),
          ),
        ],
      ),
    );
    whenListen(
      bloc, const Stream<AnalysisState>.empty(), initialState: withSummary,
    );

    await tester.pumpWidget(
      BlocProvider<AnalysisBloc>.value(
        value: bloc, child: const MaterialApp(home: WebReportsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jan 2026'), findsOneWidget);
    expect(find.text('300.00'), findsOneWidget);
  });

  testWidgets('Export CSV button is disabled when no cost data is loaded', (
    tester,
  ) async {
    final bloc = MockAnalysisBloc();
    whenListen(
      bloc, const Stream<AnalysisState>.empty(),
      initialState: const AnalysisState(),
    );

    await tester.pumpWidget(
      BlocProvider<AnalysisBloc>.value(
        value: bloc, child: const MaterialApp(home: WebReportsPage()),
      ),
    );
    await tester.pump();

    final button = find.widgetWithText(ElevatedButton, 'Export CSV');
    expect(button, findsOneWidget);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
  });

  testWidgets(
    'Export CSV button is enabled when data is loaded and invokes the '
    'injected download callback with CSV rows, without throwing',
    (tester) async {
      final bloc = MockAnalysisBloc();
      whenListen(
        bloc, const Stream<AnalysisState>.empty(), initialState: loaded,
      );
      String? capturedFilename;
      String? capturedCsv;

      await tester.pumpWidget(
        BlocProvider<AnalysisBloc>.value(
          value: bloc,
          child: MaterialApp(
            home: WebReportsPage(
              onExportCsv: (filename, csv) {
                capturedFilename = filename;
                capturedCsv = csv;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.widgetWithText(ElevatedButton, 'Export CSV');
      expect(button, findsOneWidget);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);

      await tester.tap(button);
      await tester.pump();

      expect(capturedFilename, isNotNull);
      expect(capturedFilename, endsWith('.csv'));
      expect(capturedCsv, contains('Maize Season 1'));
    },
  );
}
