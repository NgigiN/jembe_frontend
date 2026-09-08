import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:farm_tracker/features/farm/presentation/bloc/analysis_state.dart';

part 'analysis_event.dart';

class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  AnalysisBloc({required this.repository}) : super(const AnalysisState()) {
    on<LoadTotalCostsBySeason>(_onLoadTotalCostsBySeason);
    on<LoadCostBreakdown>(_onLoadCostBreakdown);
    on<LoadAnnualCostSummary>(_onLoadAnnualCostSummary);
  }
  final AnalysisRepository repository;

  Future<void> _onLoadTotalCostsBySeason(
    LoadTotalCostsBySeason event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await repository.getTotalCostsBySeason(
      const AnalyticsScope.all(),
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoading: false,
          error: resolveFailureMessage(failure, 'Failed to load cost summary'),
        ),
      ),
      (totalCosts) =>
          emit(state.copyWith(isLoading: false, detailedCosts: totalCosts)),
    );
  }

  Future<void> _onLoadCostBreakdown(
    LoadCostBreakdown event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await repository.getCostBreakdownByInputType(
      const AnalyticsScope.all(),
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoading: false,
          error: resolveFailureMessage(
            failure,
            'Failed to load cost breakdown',
          ),
        ),
      ),
      (breakdowns) =>
          emit(state.copyWith(isLoading: false, breakdowns: breakdowns)),
    );
  }

  Future<void> _onLoadAnnualCostSummary(
    LoadAnnualCostSummary event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await repository.getAnnualCostSummary(
      event.startDate,
      event.endDate,
      const AnalyticsScope.all(),
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoading: false,
          error: resolveFailureMessage(
            failure,
            'Failed to load annual summary',
          ),
        ),
      ),
      (summaries) =>
          emit(state.copyWith(isLoading: false, summaries: summaries)),
    );
  }
}
