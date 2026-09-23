import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';
import 'package:farm_tracker/features/feed/presentation/pages/feed_page.dart';
import 'package:farm_tracker/features/web_console/presentation/theme/web_console_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [FeedView] rather than the page: the role split is the part
/// worth guarding, and it is a function of the data the view is handed.
Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: WebConsoleTheme.light(), home: Scaffold(body: view)),
  );
  await tester.pump();
}

FeedEntry _entry(String type, String summary) => FeedEntry(
  entityType: type,
  summary: summary,
  loggedByUserId: 1,
  loggedByFirstName: 'Amina',
  loggedByLastName: 'Kamau',
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

void main() {
  testWidgets('renders an entry with who logged it', (tester) async {
    await _pump(
      tester,
      FeedView(
        farmName: 'Keringet',
        role: FarmRole.owner,
        entries: [_entry('activity', 'Weeding — Maize, West Plot')],
      ),
    );

    expect(find.text('Weeding — Maize, West Plot'), findsOneWidget);
    expect(find.text('Amina Kamau'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
  });

  testWidgets('an entry whose author is gone still names the column', (
    tester,
  ) async {
    await _pump(
      tester,
      FeedView(
        farmName: 'Keringet',
        role: FarmRole.owner,
        entries: [
          FeedEntry(
            entityType: 'input',
            summary: 'CAN fertilizer 50 kg',
            loggedByUserId: null,
            loggedByFirstName: null,
            loggedByLastName: null,
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );

    expect(find.text('Former member'), findsOneWidget);
  });

  testWidgets('a worker sees no amounts and is told why', (tester) async {
    await _pump(
      tester,
      FeedView(
        farmName: 'Keringet',
        role: FarmRole.worker,
        entries: [_entry('input', 'Broiler feed 50 kg')],
      ),
    );

    // The column is absent, not blanked (DESIGN_SPEC §5).
    expect(find.text('AMOUNT'), findsNothing);
    expect(
      find.text(
        'Amounts on inputs and sales are shown to owners and managers only.',
      ),
      findsOneWidget,
    );
    expect(find.text('Hidden'), findsOneWidget);
  });

  testWidgets('staff see the amount column', (tester) async {
    await _pump(
      tester,
      FeedView(
        farmName: 'Keringet',
        role: FarmRole.manager,
        entries: [_entry('input', 'Broiler feed 50 kg')],
      ),
    );

    expect(find.text('AMOUNT'), findsOneWidget);
  });

  testWidgets('an empty feed points at where logging happens', (tester) async {
    await _pump(
      tester,
      const FeedView(
        farmName: 'Keringet',
        role: FarmRole.owner,
        entries: [],
      ),
    );

    expect(find.text('Nothing logged yet'), findsOneWidget);
  });
}
