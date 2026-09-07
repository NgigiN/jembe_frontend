import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/repositories/dashboard_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Online-only summary bloc (Phase 8 B1): fetches `GET /api/v1/dashboard`
/// once and exposes its `counts`/`totals` for the landing screens
/// (`PlantsPage`/`AnimalsPage`) to source their step-card counts from,
/// instead of each screen firing a list GET purely to learn a count.
///
/// Callers gate dispatching [GetDashboardEvent] on `!OfflineConfig.enabled`
/// — this bloc has no offline branch of its own (the dashboard aggregate
/// has no local mirror; see the Phase 8 B1 plan). It does NOT replace the
/// drill-down list pages' own blocs (shared singletons), and does not cover
/// `ContentBloc` — both keep fetching independently.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({required this.repository})
      : super(const DashboardInitial()) {
    on<GetDashboardEvent>(_onGetDashboard);
  }
  final DashboardRepository repository;

  Future<void> _onGetDashboard(
    GetDashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());
    final result = await repository.getDashboard();
    result.fold(
      (failure) => emit(
        DashboardError(
          resolveFailureMessage(failure, 'Failed to load dashboard'),
        ),
      ),
      (dashboard) => emit(
        DashboardLoaded(counts: dashboard.counts, totals: dashboard.totals),
      ),
    );
  }
}
