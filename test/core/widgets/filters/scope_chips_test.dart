import 'package:farm_tracker/core/widgets/filters/scope_chips.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Land _land(String id, String name) => Land(
  id: id,
  userId: 'u',
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Herd _herd(String id, String name, {DateTime? endDate}) => Herd(
  id: id,
  userId: 'u',
  name: name,
  animalTypeId: 'a',
  location: 'L',
  initialHeadCount: 1,
  currentHeadCount: 1,
  startDate: DateTime(2025),
  endDate: endDate,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

void main() {
  final lands = [_land('l2', 'River plot'), _land('l1', 'Shamba A')];
  final herds = [
    _herd('h1', 'Dairy'),
    _herd('h2', 'Broilers 2025', endDate: DateTime(2025, 6)),
  ];

  Widget wrap(AnalyticsScope scope, void Function(AnalyticsScope) onChanged) =>
      MaterialApp(
        home: Scaffold(
          body: ScopeChips(
            scope: scope,
            onChanged: onChanged,
            lands: lands,
            herds: herds,
          ),
        ),
      );

  testWidgets('farm-wide shows only tier 1', (tester) async {
    await tester.pumpWidget(wrap(const AnalyticsScope.all(), (_) {}));
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);
    expect(find.text('Shamba A'), findsNothing);
    expect(find.text('Dairy'), findsNothing);
  });

  testWidgets(
    'Plants reveals land chips sorted by name; tapping one selects the land',
    (tester) async {
      AnalyticsScope? got;
      await tester.pumpWidget(
        wrap(const AnalyticsScope.source(ScopeSource.plant), (s) => got = s),
      );
      await tester.pumpAndSettle();
      final a = tester.getTopLeft(find.text('River plot'));
      final b = tester.getTopLeft(find.text('Shamba A'));
      expect(a.dx, lessThan(b.dx), reason: 'sorted by name');
      expect(find.text('Dairy'), findsNothing);
      await tester.tap(find.text('Shamba A'));
      expect(got, const AnalyticsScope.land('l1'));
    },
  );

  testWidgets('tapping the selected land chip again drops back to Plants', (
    tester,
  ) async {
    AnalyticsScope? got;
    await tester.pumpWidget(
      wrap(const AnalyticsScope.land('l1'), (s) => got = s),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shamba A'));
    expect(got, const AnalyticsScope.source(ScopeSource.plant));
  });

  testWidgets(
    'Animals shows active herds and an Ended (n) chip that reveals ended herds',
    (tester) async {
      AnalyticsScope? got;
      await tester.pumpWidget(
        wrap(const AnalyticsScope.source(ScopeSource.animal), (s) => got = s),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dairy'), findsOneWidget);
      expect(find.text('Broilers 2025'), findsNothing);
      expect(find.text('Ended (1)'), findsOneWidget);
      await tester.tap(find.text('Ended (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Broilers 2025'), findsOneWidget);
      await tester.tap(find.text('Broilers 2025'));
      expect(got, const AnalyticsScope.herd('h2'));
    },
  );

  testWidgets('tier-1 tap emits the source scope (clears any land)', (
    tester,
  ) async {
    AnalyticsScope? got;
    await tester.pumpWidget(
      wrap(const AnalyticsScope.land('l1'), (s) => got = s),
    );
    await tester.tap(find.text('Animals'));
    expect(got, const AnalyticsScope.source(ScopeSource.animal));
    await tester.tap(find.text('All'));
    expect(got, const AnalyticsScope.all());
  });

  testWidgets('no lands shows a hint instead of an empty row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScopeChips(
            scope: const AnalyticsScope.source(ScopeSource.plant),
            onChanged: (_) {},
            lands: const [],
            herds: herds,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No lands registered yet'), findsOneWidget);
  });
}
