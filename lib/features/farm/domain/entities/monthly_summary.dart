import 'package:equatable/equatable.dart';

class MonthlySummary extends Equatable {

  const MonthlySummary({
    required this.month,
    required this.totalCosts,
    required this.totalRevenue,
    required this.profit,
    required this.breakdown,
  });
  final String month;
  final double totalCosts;
  final double totalRevenue;
  final double profit;
  final MonthlySummaryBreakdown breakdown;

  @override
  List<Object?> get props => [month, totalCosts, totalRevenue, profit, breakdown];
}

class MonthlySummaryBreakdown extends Equatable {

  const MonthlySummaryBreakdown({
    required this.costs,
    required this.revenue,
  });
  final MonthlyCostBreakdown costs;
  final MonthlyRevenueBreakdown revenue;

  @override
  List<Object?> get props => [costs, revenue];
}

class MonthlyCostBreakdown extends Equatable {

  const MonthlyCostBreakdown({
    required this.plant,
    required this.animal,
    required this.infrastructure,
  });
  final double plant;
  final double animal;
  final double infrastructure;

  @override
  List<Object?> get props => [plant, animal, infrastructure];
}

class MonthlyRevenueBreakdown extends Equatable {

  const MonthlyRevenueBreakdown({
    required this.plant,
    required this.animal,
  });
  final double plant;
  final double animal;

  @override
  List<Object?> get props => [plant, animal];
}
