import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_annual_cost_summary.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_total_costs_by_season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:farm_tracker/features/farm/presentation/bloc/analysis_state.dart';

part 'analysis_event.dart';

class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {

  AnalysisBloc({
    required this.getTotalCostsBySeason,
    required this.getCostBreakdown,
    required this.getAnnualCostSummary,
  }) : super(const AnalysisState()) {
    on<LoadTotalCostsBySeason>(_onLoadTotalCostsBySeason);
    on<LoadCostBreakdown>(_onLoadCostBreakdown);
    on<LoadAnnualCostSummary>(_onLoadAnnualCostSummary);
  }
  final GetTotalCostsBySeason getTotalCostsBySeason;
  final GetCostBreakdown getCostBreakdown;
  final GetAnnualCostSummary getAnnualCostSummary;

  Future<void> _onLoadTotalCostsBySeason(
    LoadTotalCostsBySeason event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await getTotalCostsBySeason(NoParams());
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: resolveFailureMessage(failure, 'Failed to load cost summary'))),
      (totalCosts) => emit(state.copyWith(isLoading: false, detailedCosts: totalCosts)),
    );
  }

  Future<void> _onLoadCostBreakdown(
    LoadCostBreakdown event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await getCostBreakdown(NoParams());
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: resolveFailureMessage(failure, 'Failed to load cost breakdown'))),
      (breakdowns) => emit(state.copyWith(isLoading: false, breakdowns: breakdowns)),
    );
  }

  Future<void> _onLoadAnnualCostSummary(
    LoadAnnualCostSummary event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await getAnnualCostSummary(
      GetAnnualCostSummaryParams(
        startDate: event.startDate,
        endDate: event.endDate,
      ),
    );
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: resolveFailureMessage(failure, 'Failed to load annual summary'))),
      (summaries) => emit(state.copyWith(isLoading: false, summaries: summaries)),
    );
  }
}
