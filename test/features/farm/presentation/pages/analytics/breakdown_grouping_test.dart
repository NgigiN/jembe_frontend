import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/breakdown_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

CostBreakdown _row(String cat, String origin, double cost, double pct) =>
    CostBreakdown(
      category: cat,
      type: 'plant',
      origin: origin,
      totalCost: cost,
      percentage: pct,
    );

void main() {
  test('groups by category, sums cost and percentage, sorts groups and origins '
      'by cost desc', () {
    final groups = groupBreakdowns([
      _row('Seeds', 'S1', 100, 10),
      _row('Labour', 'S1', 500, 50),
      _row('Seeds', 'S2', 300, 30),
      _row('Fuel', 'S2', 100, 10),
    ]);
    expect(groups.map((g) => g.category), ['Labour', 'Seeds', 'Fuel']);
    final seeds = groups[1];
    expect(seeds.totalCost, 400);
    expect(seeds.percentage, 40);
    expect(seeds.origins.map((o) => o.origin), ['S2', 'S1']);
  });

  test('empty in, empty out', () {
    expect(groupBreakdowns(const []), isEmpty);
  });
}
