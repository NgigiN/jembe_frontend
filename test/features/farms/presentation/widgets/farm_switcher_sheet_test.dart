import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/widgets/farm_switcher_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Farm _farm(int id, String name, FarmRole role) => Farm(
  id: id,
  name: name,
  location: 'Kiambu',
  fiscalYearStartMonth: 1,
  ownerUserId: 1,
  successorUserId: null,
  maxMembers: 5,
  role: role,
  memberCount: 1,
  isDefault: id == 1,
);

final _farms = [
  _farm(1, 'Kiambu Farm', FarmRole.owner),
  _farm(2, 'Nakuru Plot', FarmRole.manager),
  _farm(3, 'Demo Farm', FarmRole.worker),
];

void main() {
  late List<Farm> selected;
  late int creates;
  late int manages;

  setUp(() {
    selected = [];
    creates = 0;
    manages = 0;
  });

  Future<void> pump(WidgetTester tester, {int? currentFarmId = 1}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FarmSwitcherSheet(
              farms: _farms,
              currentFarmId: currentFarmId,
              onSelect: selected.add,
              onCreate: () => creates++,
              onManage: () => manages++,
            ),
          ),
        ),
      );

  testWidgets('lists every farm with a sentence-case role', (tester) async {
    await pump(tester);

    expect(find.text('Kiambu Farm'), findsOneWidget);
    expect(find.text('Nakuru Plot'), findsOneWidget);
    expect(find.text('Demo Farm'), findsOneWidget);
    // Not the server's lowercase wire token, which reads like a bug.
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Worker'), findsOneWidget);
    expect(find.text('owner'), findsNothing);
  });

  testWidgets('marks the current farm with a filled check', (tester) async {
    await pump(tester, currentFarmId: 2);

    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Nakuru Plot'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.selected, isTrue);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('selecting another farm reports it', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Nakuru Plot'));
    await tester.pump();

    expect(selected.single.id, 2);
  });

  testWidgets(
    'tapping the CURRENT farm reports nothing - re-selecting it would '
    'remount the whole tree for no change',
    (tester) async {
      await pump(tester, currentFarmId: 2);

      await tester.tap(find.text('Nakuru Plot'));
      await tester.pump();

      expect(selected, isEmpty);
    },
  );

  testWidgets('create and manage are reachable from the sheet', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Create farm'));
    await tester.pump();
    await tester.tap(find.text('Manage'));
    await tester.pump();

    expect(creates, 1);
    expect(manages, 1);
  });
}
