import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';

/// Holds all three cost datasets at once so loading one (e.g. the cost
/// breakdown) never evicts another already-loaded dataset (e.g. the
/// detailed costs by season). Each field is populated independently by its
/// own `AnalysisBloc` handler.
class AnalysisState extends Equatable {
  const AnalysisState({
    this.detailedCosts,
    this.breakdowns,
    this.summaries,
    this.isLoading = false,
    this.error,
  });

  final FarmDetailedCost? detailedCosts;
  final List<CostBreakdown>? breakdowns;
  final List<MonthlySummary>? summaries;
  final bool isLoading;
  final String? error;

  AnalysisState copyWith({
    FarmDetailedCost? detailedCosts,
    List<CostBreakdown>? breakdowns,
    List<MonthlySummary>? summaries,
    bool? isLoading,
    String? error,
  }) => AnalysisState(
        detailedCosts: detailedCosts ?? this.detailedCosts,
        breakdowns: breakdowns ?? this.breakdowns,
        summaries: summaries ?? this.summaries,
        isLoading: isLoading ?? this.isLoading,
        // Not `error ?? this.error` — a handler must be able to clear a
        // previous error by passing `error: null`.
        error: error,
      );

  @override
  List<Object?> get props => [detailedCosts, breakdowns, summaries, isLoading, error];
}
