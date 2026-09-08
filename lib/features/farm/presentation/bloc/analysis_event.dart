part of 'analysis_bloc.dart';

abstract class AnalysisEvent extends Equatable {
  const AnalysisEvent();

  @override
  List<Object> get props => [];
}

/// [forceRefresh] bypasses the per-scope cache (pull-to-refresh).
class LoadTotalCostsBySeason extends AnalysisEvent {
  const LoadTotalCostsBySeason({this.forceRefresh = false});
  final bool forceRefresh;

  @override
  List<Object> get props => [forceRefresh];
}

class LoadCostBreakdown extends AnalysisEvent {
  const LoadCostBreakdown({this.forceRefresh = false});
  final bool forceRefresh;

  @override
  List<Object> get props => [forceRefresh];
}

class LoadAnnualCostSummary extends AnalysisEvent {
  const LoadAnnualCostSummary(
    this.startDate,
    this.endDate, {
    this.forceRefresh = false,
  });
  final DateTime startDate;
  final DateTime endDate;
  final bool forceRefresh;

  @override
  List<Object> get props => [startDate, endDate, forceRefresh];
}

/// Sets the shared scope and reloads every slice that currently holds data.
class AnalysisScopeChanged extends AnalysisEvent {
  const AnalysisScopeChanged(this.scope);
  final AnalyticsScope scope;

  @override
  List<Object> get props => [scope];
}
