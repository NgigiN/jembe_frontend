import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';

class MonthlySummaryModel extends MonthlySummary {
  const MonthlySummaryModel({
    required super.month,
    required super.totalCosts,
    required super.totalRevenue,
    required super.profit,
    required super.breakdown,
  });

  factory MonthlySummaryModel.fromJson(Map<String, dynamic> json) {
    return MonthlySummaryModel(
      month: (json['month'] as String?) ?? '',
      totalCosts: ((json['total_costs'] as num?) ?? 0).toDouble(),
      totalRevenue: ((json['total_revenue'] as num?) ?? 0).toDouble(),
      profit: ((json['profit'] as num?) ?? 0).toDouble(),
      breakdown: MonthlySummaryBreakdownModel.fromJson(
        (json['breakdown'] as Map<String, dynamic>?) ??
            {'costs': {}, 'revenue': {}},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'total_costs': totalCosts,
      'total_revenue': totalRevenue,
      'profit': profit,
      'breakdown': (breakdown as MonthlySummaryBreakdownModel).toJson(),
    };
  }
}

class MonthlySummaryBreakdownModel extends MonthlySummaryBreakdown {
  const MonthlySummaryBreakdownModel({
    required super.costs,
    required super.revenue,
  });

  factory MonthlySummaryBreakdownModel.fromJson(Map<String, dynamic> json) {
    return MonthlySummaryBreakdownModel(
      costs: MonthlyCostBreakdownModel.fromJson(
        (json['costs'] as Map<String, dynamic>?) ?? {},
      ),
      revenue: MonthlyRevenueBreakdownModel.fromJson(
        (json['revenue'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'costs': (costs as MonthlyCostBreakdownModel).toJson(),
      'revenue': (revenue as MonthlyRevenueBreakdownModel).toJson(),
    };
  }
}

class MonthlyCostBreakdownModel extends MonthlyCostBreakdown {
  const MonthlyCostBreakdownModel({
    required super.plant,
    required super.animal,
    required super.infrastructure,
  });

  factory MonthlyCostBreakdownModel.fromJson(Map<String, dynamic> json) {
    return MonthlyCostBreakdownModel(
      plant: ((json['plant'] as num?) ?? 0).toDouble(),
      animal: ((json['animal'] as num?) ?? 0).toDouble(),
      infrastructure: ((json['infrastructure'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'plant': plant, 'animal': animal, 'infrastructure': infrastructure};
  }
}

class MonthlyRevenueBreakdownModel extends MonthlyRevenueBreakdown {
  const MonthlyRevenueBreakdownModel({
    required super.plant,
    required super.animal,
  });

  factory MonthlyRevenueBreakdownModel.fromJson(Map<String, dynamic> json) {
    return MonthlyRevenueBreakdownModel(
      plant: ((json['plant'] as num?) ?? 0).toDouble(),
      animal: ((json['animal'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'plant': plant, 'animal': animal};
  }
}
