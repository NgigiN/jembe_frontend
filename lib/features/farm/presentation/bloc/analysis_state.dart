part of 'analysis_bloc.dart';

abstract class AnalysisState extends Equatable {
  const AnalysisState();

  @override
  List<Object> get props => [];
}

class AnalysisInitial extends AnalysisState {}

class AnalysisLoading extends AnalysisState {}

class AnalysisError extends AnalysisState {
  final String message;

  const AnalysisError(this.message);

  @override
  List<Object> get props => [message];
}

class TotalCostsBySeasonLoaded extends AnalysisState {
  final FarmDetailedCost detailedCosts;

  const TotalCostsBySeasonLoaded(this.detailedCosts);

  @override
  List<Object> get props => [detailedCosts];
}

class CostBreakdownLoaded extends AnalysisState {
  final List<CostBreakdown> breakdowns;

  const CostBreakdownLoaded(this.breakdowns);

  @override
  List<Object> get props => [breakdowns];
}

class AnnualCostSummaryLoaded extends AnalysisState {
  final List<AnnualCostSummary> summaries;

  const AnnualCostSummaryLoaded(this.summaries);

  @override
  List<Object> get props => [summaries];
}
