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
      month: json['month'] ?? '',
      totalCosts: (json['total_costs'] ?? 0.0).toDouble(),
      totalRevenue: (json['total_revenue'] ?? 0.0).toDouble(),
      profit: (json['profit'] ?? 0.0).toDouble(),
      breakdown: MonthlySummaryBreakdownModel.fromJson(
        json['breakdown'] ?? {'costs': {}, 'revenue': {}},
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
      costs: MonthlyCostBreakdownModel.fromJson(json['costs'] ?? {}),
      revenue: MonthlyRevenueBreakdownModel.fromJson(json['revenue'] ?? {}),
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
      plant: (json['plant'] ?? 0.0).toDouble(),
      animal: (json['animal'] ?? 0.0).toDouble(),
      infrastructure: (json['infrastructure'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plant': plant,
      'animal': animal,
      'infrastructure': infrastructure,
    };
  }
}

class MonthlyRevenueBreakdownModel extends MonthlyRevenueBreakdown {
  const MonthlyRevenueBreakdownModel({
    required super.plant,
    required super.animal,
  });

  factory MonthlyRevenueBreakdownModel.fromJson(Map<String, dynamic> json) {
    return MonthlyRevenueBreakdownModel(
      plant: (json['plant'] ?? 0.0).toDouble(),
      animal: (json['animal'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plant': plant,
      'animal': animal,
    };
  }
}
