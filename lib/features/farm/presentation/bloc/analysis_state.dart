import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';

/// One dataset's status. [data] survives a reload (rule 14: no flicker to
/// empty); [loadedFor] records the scope (or annual key) [data] belongs to,
/// so a page can tell "old scope, refreshing" from "current".
class AnalysisSlice<T> extends Equatable {
  const AnalysisSlice({
    this.data,
    this.isLoading = false,
    this.error,
    this.loadedFor,
  });
  final T? data;
  final bool isLoading;
  final String? error;
  final Object? loadedFor;

  AnalysisSlice<T> copyWith({
    T? data,
    bool? isLoading,
    String? error,
    Object? loadedFor,
    bool clearError = false,
  }) => AnalysisSlice<T>(
    data: data ?? this.data,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    loadedFor: loadedFor ?? this.loadedFor,
  );

  @override
  List<Object?> get props => [data, isLoading, error, loadedFor];
}

/// Holds the scope SHARED by the three analytics pages plus one independent
/// slice per dataset (spec 2026-09-08 D4, §4.3): loading or failing one
/// dataset never touches another.
class AnalysisState extends Equatable {
  const AnalysisState({
    this.scope = const AnalyticsScope.all(),
    this.detailedCosts = const AnalysisSlice(),
    this.breakdowns = const AnalysisSlice(),
    this.summaries = const AnalysisSlice(),
  });
  final AnalyticsScope scope;
  final AnalysisSlice<FarmDetailedCost> detailedCosts;
  final AnalysisSlice<List<CostBreakdown>> breakdowns;
  final AnalysisSlice<List<MonthlySummary>> summaries;

  AnalysisState copyWith({
    AnalyticsScope? scope,
    AnalysisSlice<FarmDetailedCost>? detailedCosts,
    AnalysisSlice<List<CostBreakdown>>? breakdowns,
    AnalysisSlice<List<MonthlySummary>>? summaries,
  }) => AnalysisState(
    scope: scope ?? this.scope,
    detailedCosts: detailedCosts ?? this.detailedCosts,
    breakdowns: breakdowns ?? this.breakdowns,
    summaries: summaries ?? this.summaries,
  );

  @override
  List<Object?> get props => [scope, detailedCosts, breakdowns, summaries];
}
