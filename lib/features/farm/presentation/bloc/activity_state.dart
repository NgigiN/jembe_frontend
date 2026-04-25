import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';

abstract class ActivityState extends Equatable {
  const ActivityState({this.activities = const []});
  final List<Activity> activities;

  @override
  List<Object> get props => [activities];
}

class ActivityInitial extends ActivityState {}

class ActivityLoading extends ActivityState {
  const ActivityLoading({super.activities});
}

class ActivityLoaded extends ActivityState {
  const ActivityLoaded({required super.activities});

  @override
  List<Object> get props => [activities];
}

class ActivityError extends ActivityState {
  const ActivityError(this.message, {super.activities});
  final String message;

  @override
  List<Object> get props => [message, activities];
}
