import 'package:farm_tracker/features/farm/data/models/activity_model.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';

/// Parses `GET /api/v1/dashboard` (Phase 8 A1) — a fresh, snake_case-only
/// endpoint, so unlike the older farm models (`ActivityModel.fromJson` etc.)
/// this needs no dual `PascalCase`/`snake_case` key tolerance.
class DashboardModel extends Dashboard {
  const DashboardModel({
    required super.counts,
    required super.totals,
    required super.recent,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      counts: DashboardCountsModel.fromJson(
        json['counts'] as Map<String, dynamic>? ?? const {},
      ),
      totals: DashboardTotalsModel.fromJson(
        json['totals'] as Map<String, dynamic>? ?? const {},
      ),
      recent: DashboardRecentModel.fromJson(
        json['recent'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class DashboardCountsModel extends DashboardCounts {
  const DashboardCountsModel({
    required super.lands,
    required super.plants,
    required super.seasons,
    required super.harvests,
    required super.animalTypes,
    required super.herds,
  });

  factory DashboardCountsModel.fromJson(Map<String, dynamic> json) {
    return DashboardCountsModel(
      lands: ((json['lands'] as num?) ?? 0).toInt(),
      plants: ((json['plants'] as num?) ?? 0).toInt(),
      seasons: ((json['seasons'] as num?) ?? 0).toInt(),
      harvests: ((json['harvests'] as num?) ?? 0).toInt(),
      animalTypes: ((json['animal_types'] as num?) ?? 0).toInt(),
      herds: ((json['herds'] as num?) ?? 0).toInt(),
    );
  }
}

class DashboardTotalsModel extends DashboardTotals {
  const DashboardTotalsModel({
    required super.totalCosts,
    required super.totalRevenue,
    required super.profit,
  });

  factory DashboardTotalsModel.fromJson(Map<String, dynamic> json) {
    return DashboardTotalsModel(
      totalCosts: ((json['total_costs'] as num?) ?? 0).toDouble(),
      totalRevenue: ((json['total_revenue'] as num?) ?? 0).toDouble(),
      profit: ((json['profit'] as num?) ?? 0).toDouble(),
    );
  }
}

class DashboardRecentModel extends DashboardRecent {
  const DashboardRecentModel({
    required super.activities,
    required super.harvests,
    required super.inputs,
    required super.revenues,
  });

  factory DashboardRecentModel.fromJson(Map<String, dynamic> json) {
    return DashboardRecentModel(
      activities: ((json['activities'] as List<dynamic>?) ?? const [])
          .map((e) => ActivityModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      harvests: ((json['harvests'] as List<dynamic>?) ?? const [])
          .map((e) => HarvestModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      inputs: ((json['inputs'] as List<dynamic>?) ?? const [])
          .map((e) => InputModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      revenues: ((json['revenues'] as List<dynamic>?) ?? const [])
          .map((e) => RevenueModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
