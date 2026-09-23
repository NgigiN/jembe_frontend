import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_farms_page.dart';
import 'package:farm_tracker/features/web_console/presentation/theme/web_console_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: WebConsoleTheme.light(), home: Scaffold(body: view)),
  );
  await tester.pump();
}

const _farms = [
  Farm(
    id: 1,
    name: 'Keringet',
    location: 'Nakuru',
    fiscalYearStartMonth: 1,
    ownerUserId: 1,
    successorUserId: null,
    maxMembers: 10,
    role: FarmRole.owner,
    memberCount: 3,
    isDefault: true,
  ),
  Farm(
    id: 2,
    name: 'Kamburu',
    location: "Murang'a",
    fiscalYearStartMonth: 1,
    ownerUserId: 1,
    successorUserId: null,
    maxMembers: 10,
    role: FarmRole.manager,
    memberCount: 1,
    isDefault: false,
  ),
];

void main() {
  testWidgets('the current farm is tagged and the others offer a switch', (
    tester,
  ) async {
    await _pump(tester, const FarmsView(farms: _farms, currentFarmId: 1));

    // Two matches on purpose: the row, and the create panel's example
    // placeholder.
    expect(find.text('Keringet'), findsWidgets);
    expect(find.text('Kamburu'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
  });

  testWidgets('switching reports the farm that was chosen', (tester) async {
    Farm? switched;
    await _pump(
      tester,
      FarmsView(
        farms: _farms,
        currentFarmId: 1,
        onSwitch: (farm) => switched = farm,
      ),
    );

    await tester.tap(find.text('Switch'));
    await tester.pump();

    expect(switched?.id, 2);
  });

  testWidgets('with no farms it invites you to create one', (tester) async {
    await _pump(tester, const FarmsView(farms: []));

    expect(find.text('No farms yet'), findsOneWidget);
    expect(find.text('Create farm'), findsOneWidget);
  });
}
