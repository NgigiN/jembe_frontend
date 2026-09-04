import 'package:farm_tracker/features/farm/presentation/widgets/enterprise_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final activeSeason = Enterprise(
    id: 'season-1',
    kind: EnterpriseKind.season,
    name: 'Long Rains 2026',
    startDate: DateTime(2026, 3),
  );
  final closedHerd = Enterprise(
    id: 'herd-1',
    kind: EnterpriseKind.herd,
    name: 'Broiler Batch 1',
    startDate: DateTime(2026),
    endDate: DateTime(2026, 2),
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows "All Active" label when nothing is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        EnterprisePicker(
          enterprises: [activeSeason, closedHerd],
          selected: null,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('All Active Seasons/Herds'), findsOneWidget);
  });

  testWidgets(
    'tapping opens a sheet listing active and completed enterprises separately',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          EnterprisePicker(
            enterprises: [activeSeason, closedHerd],
            selected: null,
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(EnterprisePicker));
      await tester.pumpAndSettle();

      expect(find.text('Long Rains 2026'), findsOneWidget);
      expect(find.text('COMPLETED (1)'), findsOneWidget);
      expect(find.text('Broiler Batch 1'), findsNothing); // inside collapsed ExpansionTile
    },
  );

  testWidgets('selecting an active enterprise calls onChanged and closes the sheet', (
    tester,
  ) async {
    Enterprise? selected;
    await tester.pumpWidget(
      wrap(
        EnterprisePicker(
          enterprises: [activeSeason, closedHerd],
          selected: null,
          onChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.byType(EnterprisePicker));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Long Rains 2026'));
    await tester.pumpAndSettle();

    expect(selected, activeSeason);
    expect(find.text('Search seasons/herds...'), findsNothing); // sheet closed
  });

  testWidgets('search filters the visible list by name', (tester) async {
    await tester.pumpWidget(
      wrap(
        EnterprisePicker(
          enterprises: [activeSeason, closedHerd],
          selected: null,
          onChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(EnterprisePicker));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'broiler',
    );
    await tester.pumpAndSettle();

    expect(find.text('Long Rains 2026'), findsNothing);
    expect(find.text('COMPLETED (1)'), findsOneWidget);
  });
}
