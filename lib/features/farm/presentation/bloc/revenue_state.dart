import 'package:equatable/equatable.dart';
import '../../domain/entities/revenue.dart';

abstract class RevenueState extends Equatable {
  final List<Revenue> revenues;

  const RevenueState({this.revenues = const []});

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
  final String message;

  const RevenueError(this.message, {super.revenues});

  @override
  List<Object> get props => [message, revenues];
}

class RevenueAdded extends RevenueState {
  final Revenue revenue;

  const RevenueAdded({required this.revenue, super.revenues});

  @override
  List<Object> get props => [revenue, revenues];
}

class RevenueUpdated extends RevenueState {
  final Revenue revenue;

  const RevenueUpdated({required this.revenue, super.revenues});

  @override
  List<Object> get props => [revenue, revenues];
}

class RevenueDeleted extends RevenueState {
  const RevenueDeleted({super.revenues});
}


