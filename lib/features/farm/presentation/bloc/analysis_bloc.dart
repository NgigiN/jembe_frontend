import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/farm_detailed_cost.dart';
import '../../domain/entities/cost_breakdown.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/usecases/get_total_costs_by_season.dart';
import '../../domain/usecases/get_cost_breakdown.dart';
import '../../domain/usecases/get_annual_cost_summary.dart';

part 'analysis_event.dart';
part 'analysis_state.dart';

class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  final GetTotalCostsBySeason getTotalCostsBySeason;
  final GetCostBreakdown getCostBreakdown;
  final GetAnnualCostSummary getAnnualCostSummary;

  AnalysisBloc({
    required this.getTotalCostsBySeason,
    required this.getCostBreakdown,
    required this.getAnnualCostSummary,
  }) : super(AnalysisInitial()) {
    on<LoadTotalCostsBySeason>(_onLoadTotalCostsBySeason);
    on<LoadCostBreakdown>(_onLoadCostBreakdown);
    on<LoadAnnualCostSummary>(_onLoadAnnualCostSummary);
  }

  Future<void> _onLoadTotalCostsBySeason(
    LoadTotalCostsBySeason event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(AnalysisLoading());
    final result = await getTotalCostsBySeason(NoParams());
    result.fold(
      (failure) => emit(AnalysisError('Failed to load total costs by season')),
      (totalCosts) => emit(TotalCostsBySeasonLoaded(totalCosts)),
    );
  }

  Future<void> _onLoadCostBreakdown(
    LoadCostBreakdown event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(AnalysisLoading());
    final result = await getCostBreakdown(NoParams());
    result.fold(
      (failure) => emit(AnalysisError('Failed to load cost breakdown')),
      (breakdowns) => emit(CostBreakdownLoaded(breakdowns)),
    );
  }

  Future<void> _onLoadAnnualCostSummary(
    LoadAnnualCostSummary event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(AnalysisLoading());
    final result = await getAnnualCostSummary(NoParams());
    result.fold(
      (failure) => emit(AnalysisError('Failed to load annual cost summary')),
      (summaries) => emit(AnnualCostSummaryLoaded(summaries)),
    );
  }
}
