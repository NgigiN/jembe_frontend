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
      recent: _parseRecentBestEffort(json['recent']),
    );
  }
}

/// Parses `recent` best-effort: B1 only consumes `counts`/`totals` (see
/// `DashboardRecent`'s class docs), so a malformed `recent` slice — an
/// unexpected shape, or a row that doesn't match its entity model — must
/// never fail the whole dashboard fetch and block the plants/animals
/// landing screens. Any parse failure (a bad top-level shape, or a bad
/// row within it — see `DashboardRecentModel.fromJson`) yields
/// [DashboardRecent.empty], never an exception.
DashboardRecent _parseRecentBestEffort(dynamic raw) {
  try {
    return DashboardRecentModel.fromJson(
      raw is Map<String, dynamic> ? raw : const {},
    );
  } catch (_) {
    return const DashboardRecent.empty();
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
      activities: _parseRowsBestEffort(
        json['activities'],
        ActivityModel.fromJson,
      ),
      harvests: _parseRowsBestEffort(
        json['harvests'],
        HarvestModel.fromJson,
      ),
      inputs: _parseRowsBestEffort(
        json['inputs'],
        InputModel.fromJson,
      ),
      revenues: _parseRowsBestEffort(
        json['revenues'],
        RevenueModel.fromJson,
      ),
    );
  }
}

/// Parses a raw JSON list with [parseRow], skipping (not throwing on) any
/// row that isn't a JSON object or that fails to parse — a single
/// malformed `recent` row must not take down the rest of the slice. See
/// [_parseRecentBestEffort] for the outer safety net around the whole
/// `recent` block.
List<T> _parseRowsBestEffort<T>(
  dynamic rawList,
  T Function(Map<String, dynamic>) parseRow,
) {
  if (rawList is! List) return const [];
  final result = <T>[];
  for (final row in rawList) {
    if (row is! Map<String, dynamic>) continue;
    try {
      result.add(parseRow(row));
    } catch (_) {
      // Skip this row — best-effort.
    }
  }
  return result;
}
