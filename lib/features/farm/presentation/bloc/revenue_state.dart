import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';

abstract class RevenueState extends Equatable {
  const RevenueState({this.revenues = const []});
  final List<Revenue> revenues;

  @override
  List<Object> get props => [revenues];
}

class RevenueInitial extends RevenueState {}

class RevenueLoading extends RevenueState {
  const RevenueLoading({super.revenues});
}

class RevenueLoaded extends RevenueState {
  const RevenueLoaded({super.revenues});
}

class RevenueError extends RevenueState {
  const RevenueError(this.message, {super.revenues});
  final String message;

  @override
  List<Object> get props => [message, revenues];
}

class RevenueAdded extends RevenueState {
  const RevenueAdded({required this.revenue, super.revenues});
  final Revenue revenue;

  @override
  List<Object> get props => [revenue, revenues];
}

class RevenueUpdated extends RevenueState {
  const RevenueUpdated({required this.revenue, super.revenues});
  final Revenue revenue;

  @override
  List<Object> get props => [revenue, revenues];
}

class RevenueDeleted extends RevenueState {
  const RevenueDeleted({super.revenues});
}
