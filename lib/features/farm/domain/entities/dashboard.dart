import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';

/// Per-user entity counts (live rows only — soft-deleted excluded) backing
/// the `PlantsPage`/`AnimalsPage` landing-screen step summaries. Mirrors the
/// backend `GET /api/v1/dashboard` `counts` object (Phase 8 A1).
class DashboardCounts extends Equatable {
  const DashboardCounts({
    required this.lands,
    required this.plants,
    required this.seasons,
    required this.harvests,
    required this.animalTypes,
    required this.herds,
  });

  /// All counts zeroed — the "nothing loaded yet" default the bloc's
  /// pre-load states carry, mirroring the empty-list default other farm
  /// states (e.g. `LandState.lands = const []`) use for the same purpose.
  const DashboardCounts.zero()
      : lands = 0,
        plants = 0,
        seasons = 0,
        harvests = 0,
        animalTypes = 0,
        herds = 0;

  final int lands;
  final int plants;
  final int seasons;
  final int harvests;
  final int animalTypes;
  final int herds;

  @override
  List<Object?> get props => [
    lands,
    plants,
    seasons,
    harvests,
    animalTypes,
    herds,
  ];
}

/// Headline farm-wide totals, mirroring `AnalysisService.GetTotalCosts`/
/// `GetTotalRevenue`/`GetProfit` on the backend but composed once, server
/// side, into the dashboard response (Phase 8 A1).
class DashboardTotals extends Equatable {
  const DashboardTotals({
    required this.totalCosts,
    required this.totalRevenue,
    required this.profit,
  });

  const DashboardTotals.zero()
      : totalCosts = 0,
        totalRevenue = 0,
        profit = 0;

  final double totalCosts;
  final double totalRevenue;
  final double profit;

  @override
  List<Object?> get props => [totalCosts, totalRevenue, profit];
}

/// The dashboard's `id DESC LIMIT 5` slices of the transactional entities.
/// Not consumed by `PlantsPage`/`AnimalsPage` (Phase 8 B1 only needs
/// `counts`/`totals`) — parsed here so `DashboardModel.fromJson` round-trips
/// the full backend contract for a future recent-activity consumer.
class DashboardRecent extends Equatable {
  const DashboardRecent({
    required this.activities,
    required this.harvests,
    required this.inputs,
    required this.revenues,
  });

  const DashboardRecent.empty()
      : activities = const [],
        harvests = const [],
        inputs = const [],
        revenues = const [];

  final List<Activity> activities;
  final List<Harvest> harvests;
  final List<Input> inputs;
  final List<Revenue> revenues;

  @override
  List<Object?> get props => [activities, harvests, inputs, revenues];
}

class Dashboard extends Equatable {
  const Dashboard({
    required this.counts,
    required this.totals,
    required this.recent,
  });

  final DashboardCounts counts;
  final DashboardTotals totals;
  final DashboardRecent recent;

  @override
  List<Object?> get props => [counts, totals, recent];
}
