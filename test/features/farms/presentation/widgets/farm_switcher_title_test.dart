import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/farms/presentation/widgets/farm_switcher_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Farm _farm(int id, String name) => Farm(
  id: id,
  name: name,
  location: 'Kiambu',
  fiscalYearStartMonth: 1,
  ownerUserId: 1,
  successorUserId: null,
  maxMembers: 5,
  role: FarmRole.owner,
  memberCount: 1,
  isDefault: id == 1,
);

FarmLoaded _loaded(List<Farm> farms, int? currentId) => FarmLoaded(
  farms: farms,
  currentFarmId: currentId,
  currentRole: FarmRole.owner,
);

void main() {
  group('currentFarmName', () {
    test('resolves the current farm by id', () {
      final state = _loaded([_farm(1, 'Kiambu Farm'), _farm(2, 'Nakuru')], 2);
      expect(currentFarmName(state), 'Nakuru');
    });

    test('is null when the current id matches no known farm', () {
      expect(currentFarmName(_loaded([_farm(1, 'Kiambu Farm')], 99)), isNull);
    });

    test('is null for a state that has not loaded', () {
      expect(currentFarmName(FarmInitial()), isNull);
      expect(currentFarmName(const FarmError('offline')), isNull);
    });
  });

  group('canSwitchFarm', () {
    test('false with a single farm - the picker could do nothing', () {
      expect(canSwitchFarm(_loaded([_farm(1, 'Kiambu Farm')], 1)), isFalse);
    });

    test('true with more than one farm', () {
      final state = _loaded([_farm(1, 'Kiambu Farm'), _farm(2, 'Nakuru')], 1);
      expect(canSwitchFarm(state), isTrue);
    });

    test('false before farms load', () {
      expect(canSwitchFarm(FarmInitial()), isFalse);
    });
  });

  group('FarmSwitcherTitleView', () {
    late int taps;

    setUp(() => taps = 0);

    Future<void> pump(
      WidgetTester tester, {
      required String label,
      required bool canSwitch,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: FarmSwitcherTitleView(
              label: label,
              canSwitch: canSwitch,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    testWidgets('shows a caret and opens on tap when switching is possible', (
      tester,
    ) async {
      await pump(tester, label: 'Kiambu Farm', canSwitch: true);

      expect(find.text('Kiambu Farm'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      await tester.tap(find.text('Kiambu Farm'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets(
      'degrades to a plain, inert title with a single farm - no caret '
      'promising a picker that has nothing to offer',
      (tester) async {
        await pump(tester, label: 'Kiambu Farm', canSwitch: false);

        expect(find.text('Kiambu Farm'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
        expect(find.byType(InkWell), findsNothing);
      },
    );

    testWidgets('falls back to the page name before farms resolve', (
      tester,
    ) async {
      await pump(tester, label: 'Plants', canSwitch: false);

      expect(find.text('Plants'), findsOneWidget);
    });
  });
}
