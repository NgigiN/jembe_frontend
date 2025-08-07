part of 'analysis_bloc.dart';

abstract class AnalysisEvent extends Equatable {
  const AnalysisEvent();

  @override
  List<Object> get props => [];
}

class LoadTotalCostsBySeason extends AnalysisEvent {}

class LoadCostBreakdown extends AnalysisEvent {}

class LoadAnnualCostSummary extends AnalysisEvent {}
