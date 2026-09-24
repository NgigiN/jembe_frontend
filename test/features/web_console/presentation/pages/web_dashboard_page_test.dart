import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_dashboard_page.dart';
import 'package:farm_tracker/features/web_console/presentation/theme/web_console_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [DashboardView] rather than the page: the page is bloc
/// plumbing, and everything worth asserting about the Dashboard is a
/// function of the data it is handed.
Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: WebConsoleTheme.light(), home: Scaffold(body: view)),
  );
  await tester.pump();
}

const _counts = DashboardCounts(
  lands: 3,
  plants: 12,
  seasons: 2,
  harvests: 7,
  animalTypes: 4,
  herds: 5,
);

const _totals = DashboardTotals(
  totalCosts: 15900,
  totalRevenue: 12600,
  profit: -3300,
);

void main() {
  testWidgets('renders the counts and the money position', (tester) async {
    await _pump(
      tester,
      const DashboardView(
        farmName: 'Keringet',
        subtitle: 'Nakuru',
        counts: _counts,
        totals: _totals,
        entries: [],
        breakdown: [],
      ),
    );

    expect(find.text('Keringet'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('KES 15,900'), findsOneWidget);
    // A loss is written with a real minus sign, not a hyphen.
    expect(find.text('−KES 3,300'), findsOneWidget);
  });

  testWidgets('a farm with nothing in it gets the first-run checklist', (
    tester,
  ) async {
    await _pump(
      tester,
      const DashboardView(
        farmName: 'Kamburu',
        subtitle: "Murang'a",
        counts: DashboardCounts.zero(),
        totals: DashboardTotals.zero(),
        entries: [],
        breakdown: [],
      ),
    );

    expect(
      find.text("Kamburu is a blank field. Let's put something on it."),
      findsOneWidget,
    );
    expect(find.text('Add your first land plot'), findsOneWidget);
    // The working screen's card is absent, not empty.
    expect(find.text('Season log'), findsNothing);
  });

  testWidgets('an error keeps the header and offers a retry', (tester) async {
    var retried = false;
    await _pump(
      tester,
      DashboardView(
        farmName: 'Keringet',
        subtitle: 'Nakuru',
        counts: null,
        totals: null,
        entries: null,
        breakdown: null,
        errorMessage: 'GET /dashboard · 503',
        onRetry: () => retried = true,
      ),
    );

    expect(find.text("Couldn't reach Keringet"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
