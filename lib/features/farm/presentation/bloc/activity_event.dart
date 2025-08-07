import 'package:equatable/equatable.dart';
import '../../domain/entities/activity.dart';

abstract class ActivityEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetActivitiesEvent extends ActivityEvent {}

class AddActivityEvent extends ActivityEvent {
  final Activity activity;

  AddActivityEvent(this.activity);

  @override
  List<Object> get props => [activity];
}
