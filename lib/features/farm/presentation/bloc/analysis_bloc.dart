import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:farm_tracker/features/farm/presentation/bloc/analysis_state.dart';

part 'analysis_event.dart';

/// Cache key for the annual slice: the window AND the scope.
class _AnnualKey extends Equatable {
  const _AnnualKey(this.scope, this.start, this.end);
  final AnalyticsScope scope;
  final DateTime start;
  final DateTime end;

  @override
  List<Object?> get props => [scope, start, end];
}

/// Shared scope + three independent slices + a per-scope cache.
///
/// Cache policy is stale-while-revalidate: a cached scope is emitted at once
/// (no spinner) and then refreshed; `forceRefresh` skips the cache read.
/// Responses whose scope is no longer `state.scope` are dropped, so a slow
/// farm-wide reply can never overwrite a later land selection. The bloc is
/// an app-wide singleton, so scope and cache live for the session.
class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  AnalysisBloc({required this.repository}) : super(const AnalysisState()) {
    on<LoadTotalCostsBySeason>(_onLoadTotalCostsBySeason);
    on<LoadCostBreakdown>(_onLoadCostBreakdown);
    on<LoadAnnualCostSummary>(_onLoadAnnualCostSummary);
    on<AnalysisScopeChanged>(_onScopeChanged);
  }
  final AnalysisRepository repository;

  final _costsCache = <AnalyticsScope, FarmDetailedCost>{};
  final _breakdownCache = <AnalyticsScope, List<CostBreakdown>>{};
  final _annualCache = <_AnnualKey, List<MonthlySummary>>{};
  DateTime? _annualStart;
  DateTime? _annualEnd;

  Future<void> _onLoadTotalCostsBySeason(
    LoadTotalCostsBySeason event,
    Emitter<AnalysisState> emit,
  ) async {
    final scope = state.scope;
    final cached = event.forceRefresh ? null : _costsCache[scope];
    emit(
      state.copyWith(
        detailedCosts: cached != null
            ? AnalysisSlice(data: cached, loadedFor: scope)
            : state.detailedCosts.copyWith(isLoading: true, clearError: true),
      ),
    );
    final result = await repository.getTotalCostsBySeason(scope);
    if (state.scope != scope) return; // stale: a newer scope was selected
    result.fold(
      (failure) => emit(
        state.copyWith(
          detailedCosts: state.detailedCosts.copyWith(
            isLoading: false,
            error: resolveFailureMessage(
              failure,
              'Failed to load cost summary',
            ),
          ),
        ),
      ),
      (data) {
        _costsCache[scope] = data;
        emit(
          state.copyWith(
            detailedCosts: AnalysisSlice(data: data, loadedFor: scope),
          ),
        );
      },
    );
  }

  Future<void> _onLoadCostBreakdown(
    LoadCostBreakdown event,
    Emitter<AnalysisState> emit,
  ) async {
    final scope = state.scope;
    final cached = event.forceRefresh ? null : _breakdownCache[scope];
    emit(
      state.copyWith(
        breakdowns: cached != null
            ? AnalysisSlice(data: cached, loadedFor: scope)
            : state.breakdowns.copyWith(isLoading: true, clearError: true),
      ),
    );
    final result = await repository.getCostBreakdownByInputType(scope);
    if (state.scope != scope) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          breakdowns: state.breakdowns.copyWith(
            isLoading: false,
            error: resolveFailureMessage(
              failure,
              'Failed to load cost breakdown',
            ),
          ),
        ),
      ),
      (data) {
        _breakdownCache[scope] = data;
        emit(
          state.copyWith(
            breakdowns: AnalysisSlice(data: data, loadedFor: scope),
          ),
        );
      },
    );
  }

  Future<void> _onLoadAnnualCostSummary(
    LoadAnnualCostSummary event,
    Emitter<AnalysisState> emit,
  ) async {
    final scope = state.scope;
    _annualStart = event.startDate;
    _annualEnd = event.endDate;
    final key = _AnnualKey(scope, event.startDate, event.endDate);
    final cached = event.forceRefresh ? null : _annualCache[key];
    emit(
      state.copyWith(
        summaries: cached != null
            ? AnalysisSlice(data: cached, loadedFor: key)
            : state.summaries.copyWith(isLoading: true, clearError: true),
      ),
    );
    final result = await repository.getAnnualCostSummary(
      event.startDate,
      event.endDate,
      scope,
    );
    if (state.scope != scope ||
        _annualStart != event.startDate ||
        _annualEnd != event.endDate) {
      return; // stale: scope or farm year moved on
    }
    result.fold(
      (failure) => emit(
        state.copyWith(
          summaries: state.summaries.copyWith(
            isLoading: false,
            error: resolveFailureMessage(
              failure,
              'Failed to load annual summary',
            ),
          ),
        ),
      ),
      (data) {
        _annualCache[key] = data;
        emit(
          state.copyWith(
            summaries: AnalysisSlice(data: data, loadedFor: key),
          ),
        );
      },
    );
  }

  void _onScopeChanged(
    AnalysisScopeChanged event,
    Emitter<AnalysisState> emit,
  ) {
    if (event.scope == state.scope) return;
    // Swap in whatever the cache already holds for the new scope in the SAME
    // emission as the scope change, so a page never shows the previous
    // scope's rows under the newly selected chip — not even for one frame.
    // The reloads below then refresh those slices (stale-while-revalidate).
    final scope = event.scope;
    final cachedCosts = _costsCache[scope];
    final cachedBreakdowns = _breakdownCache[scope];
    final annualKey = (_annualStart != null && _annualEnd != null)
        ? _AnnualKey(scope, _annualStart!, _annualEnd!)
        : null;
    final cachedSummaries = annualKey == null ? null : _annualCache[annualKey];
    final hasCosts = state.detailedCosts.data != null;
    final hasBreakdowns = state.breakdowns.data != null;
    final hasSummaries = state.summaries.data != null;
    emit(
      state.copyWith(
        scope: scope,
        detailedCosts: hasCosts && cachedCosts != null
            ? AnalysisSlice(data: cachedCosts, loadedFor: scope)
            : null,
        breakdowns: hasBreakdowns && cachedBreakdowns != null
            ? AnalysisSlice(data: cachedBreakdowns, loadedFor: scope)
            : null,
        summaries: hasSummaries && cachedSummaries != null
            ? AnalysisSlice(data: cachedSummaries, loadedFor: annualKey)
            : null,
      ),
    );
    if (hasCosts) add(const LoadTotalCostsBySeason());
    if (hasBreakdowns) add(const LoadCostBreakdown());
    if (hasSummaries && annualKey != null) {
      add(LoadAnnualCostSummary(annualKey.start, annualKey.end));
    }
  }
}
