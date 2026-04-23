import 'package:equatable/equatable.dart';

class MonthlySummary extends Equatable {
  final String month;
  final double totalCosts;
  final double totalRevenue;
  final double profit;
  final MonthlySummaryBreakdown breakdown;

  const MonthlySummary({
    required this.month,
    required this.totalCosts,
    required this.totalRevenue,
    required this.profit,
    required this.breakdown,
  });

  @override
  List<Object?> get props => [month, totalCosts, totalRevenue, profit, breakdown];
}

class MonthlySummaryBreakdown extends Equatable {
  final MonthlyCostBreakdown costs;
  final MonthlyRevenueBreakdown revenue;

  const MonthlySummaryBreakdown({
    required this.costs,
    required this.revenue,
  });

  @override
  List<Object?> get props => [costs, revenue];
}

class MonthlyCostBreakdown extends Equatable {
  final double plant;
  final double animal;
  final double infrastructure;

  const MonthlyCostBreakdown({
    required this.plant,
    required this.animal,
    required this.infrastructure,
  });

  @override
  List<Object?> get props => [plant, animal, infrastructure];
}

class MonthlyRevenueBreakdown extends Equatable {
  final double plant;
  final double animal;

  const MonthlyRevenueBreakdown({
    required this.plant,
    required this.animal,
  });

  @override
  List<Object?> get props => [plant, animal];
}
