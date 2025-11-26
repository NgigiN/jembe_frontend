import 'package:equatable/equatable.dart';
import '../../domain/entities/activity.dart';

abstract class ActivityEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetActivitiesEvent extends ActivityEvent {
  final String? sourceType;

  GetActivitiesEvent({this.sourceType});

  @override
  List<Object> get props => [sourceType ?? ''];
}

class AddActivityEvent extends ActivityEvent {
  final Activity activity;

  AddActivityEvent(this.activity);

  @override
  List<Object> get props => [activity];
}

class UpdateActivityEvent extends ActivityEvent {
  final Activity activity;

  UpdateActivityEvent(this.activity);

  @override
  List<Object> get props => [activity];
}

class DeleteActivityEvent extends ActivityEvent {
  final String id;

  DeleteActivityEvent(this.id);

  @override
  List<Object> get props => [id];
}
