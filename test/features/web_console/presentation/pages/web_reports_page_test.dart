import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_reports_page.dart';
import 'package:farm_tracker/features/web_console/presentation/theme/web_console_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [ReportsView] rather than the page: the page is bloc
/// plumbing, and the tabs, the season total and the CSV payload are all
/// functions of the data it is handed.
Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: WebConsoleTheme.light(), home: Scaffold(body: view)),
  );
  await tester.pump();
}

final _details = [
  CostDetail(
    type: 'plant',
    id: 1,
    name: 'Maize Season 1',
    category: 'Fertilizer',
    location: 'West Plot',
    startDate: DateTime(2026, 3, 14),
    inputCost: 11300,
    activityCost: 0,
    totalCost: 11300,
  ),
];

const _breakdowns = [
  CostBreakdown(
    category: 'Fertilizer',
    type: 'plant',
    origin: 'Long rains 2026',
    totalCost: 11300,
    percentage: 100,
  ),
];

const _noBreakdown = MonthlySummaryBreakdown(
  costs: MonthlyCostBreakdown(plant: 0, animal: 0, infrastructure: 0),
  revenue: MonthlyRevenueBreakdown(plant: 0, animal: 0),
);

const _months = [
  MonthlySummary(
    month: 'Jan 2026',
    totalCosts: 100,
    totalRevenue: 400,
    profit: 300,
    breakdown: _noBreakdown,
  ),
];

void main() {
  testWidgets('cost details open first, with a season total', (tester) async {
    await _pump(
      tester,
      ReportsView(
        farmName: 'Keringet',
        year: 2026,
        details: _details,
        breakdowns: _breakdowns,
        summaries: _months,
      ),
    );

    expect(find.text('Maize Season 1'), findsOneWidget);
    expect(find.text('Season total'), findsOneWidget);
  });

  testWidgets('the annual summary tab shows a month row', (tester) async {
    await _pump(
      tester,
      ReportsView(
        farmName: 'Keringet',
        year: 2026,
        details: _details,
        breakdowns: _breakdowns,
        summaries: _months,
        tabIndex: 2,
      ),
    );

    expect(find.text('Jan 2026'), findsWidgets);
  });

  testWidgets('Export CSV is disabled until there is something to export', (
    tester,
  ) async {
    await _pump(
      tester,
      const ReportsView(
        farmName: 'Keringet',
        year: 2026,
        details: [],
        breakdowns: [],
        summaries: [],
      ),
    );

    final button = find.widgetWithText(OutlinedButton, 'Export CSV');
    expect(button, findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
  });

  testWidgets('Export CSV hands the rows to the injected download', (
    tester,
  ) async {
    String? filename;
    String? csv;

    await _pump(
      tester,
      ReportsView(
        farmName: 'Keringet',
        year: 2026,
        details: _details,
        breakdowns: _breakdowns,
        summaries: _months,
        onExportCsv: (name, content) {
          filename = name;
          csv = content;
        },
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Export CSV'));
    await tester.pump();

    expect(filename, endsWith('.csv'));
    expect(csv, contains('Maize Season 1'));
  });

  test('the CSV quotes a field containing a comma', () {
    final csv = costDetailsToCsv([
      CostDetail(
        type: 'plant',
        id: 2,
        name: 'Maize, West Plot',
        category: 'Fertilizer',
        location: '',
        startDate: DateTime(2026, 3, 14),
        inputCost: 1,
        activityCost: 2,
        totalCost: 3,
      ),
    ]);

    expect(csv, contains('"Maize, West Plot"'));
  });
}
