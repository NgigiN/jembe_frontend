import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  const DashboardLoaded({required this.counts, required this.totals});
  final DashboardCounts counts;
  final DashboardTotals totals;

  @override
  List<Object?> get props => [counts, totals];
}

class DashboardError extends DashboardState {
  const DashboardError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
