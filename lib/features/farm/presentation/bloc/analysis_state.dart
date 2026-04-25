part of 'analysis_bloc.dart';

abstract class AnalysisState extends Equatable {
  const AnalysisState();

  @override
  List<Object> get props => [];
}

class AnalysisInitial extends AnalysisState {}

class AnalysisLoading extends AnalysisState {}

class AnalysisError extends AnalysisState {

  const AnalysisError(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class TotalCostsBySeasonLoaded extends AnalysisState {

  const TotalCostsBySeasonLoaded(this.detailedCosts);
  final FarmDetailedCost detailedCosts;

  @override
  List<Object> get props => [detailedCosts];
}

class CostBreakdownLoaded extends AnalysisState {

  const CostBreakdownLoaded(this.breakdowns);
  final List<CostBreakdown> breakdowns;

  @override
  List<Object> get props => [breakdowns];
}

class AnnualCostSummaryLoaded extends AnalysisState {

  const AnnualCostSummaryLoaded(this.summaries);
  final List<MonthlySummary> summaries;

  @override
  List<Object> get props => [summaries];
}
