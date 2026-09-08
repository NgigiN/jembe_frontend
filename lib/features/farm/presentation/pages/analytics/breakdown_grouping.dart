import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';

/// One input type (category) across every season/herd in the current scope.
class BreakdownGroup extends Equatable {
  const BreakdownGroup({
    required this.category,
    required this.totalCost,
    required this.percentage,
    required this.origins,
  });
  final String category;
  final double totalCost;

  /// Sum of the server's scoped percentages, so groups still add up to ~100
  /// within the selected scope.
  final double percentage;

  /// The per-season / per-herd rows behind this category, totalCost desc.
  final List<CostBreakdown> origins;

  @override
  List<Object?> get props => [category, totalCost, percentage, origins];
}

/// Pure, O(n). The wire shape stays per (category × origin) — spec D9 — so a
/// farm with 50 seasons × 10 input types (~500 rows) reads as ~10 headers
/// instead of a 500-row wall.
List<BreakdownGroup> groupBreakdowns(List<CostBreakdown> rows) {
  final byCategory = <String, List<CostBreakdown>>{};
  for (final r in rows) {
    (byCategory[r.category] ??= []).add(r);
  }
  final groups = [
    for (final e in byCategory.entries)
      BreakdownGroup(
        category: e.key,
        totalCost: e.value.fold(0, (a, r) => a + r.totalCost),
        percentage: e.value.fold(0, (a, r) => a + r.percentage),
        origins: [...e.value]
          ..sort((a, b) => b.totalCost.compareTo(a.totalCost)),
      ),
  ]..sort((a, b) => b.totalCost.compareTo(a.totalCost));
  return groups;
}
