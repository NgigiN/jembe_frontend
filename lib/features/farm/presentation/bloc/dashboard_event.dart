import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  @override
  List<Object> get props => [];
}

/// Online-only (Phase 8 B1): fetches `GET /api/v1/dashboard` once. Callers
/// (`PlantsPage`/`AnimalsPage`) dispatch this only when
/// `!OfflineConfig.enabled` — there is no offline/Watch counterpart, since
/// the dashboard aggregate has no local mirror.
class GetDashboardEvent extends DashboardEvent {}
