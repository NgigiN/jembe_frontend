import 'package:equatable/equatable.dart';
import '../../domain/entities/activity.dart';

abstract class ActivityState extends Equatable {
  final List<Activity> activities;

  const ActivityState({this.activities = const []});

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
  final String message;

  const ActivityError(this.message, {super.activities});

  @override
  List<Object> get props => [message, activities];
}
