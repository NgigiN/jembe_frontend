import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';

abstract class ActivityEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetActivitiesEvent extends ActivityEvent {
  GetActivitiesEvent({this.sourceType});
  final String? sourceType;

  @override
  List<Object> get props => [sourceType ?? ''];
}

/// Flag-ON only: subscribes (or re-subscribes) `ActivityBloc` to
/// `repository.watchActivities(sourceType:)`, scoped exactly like the
/// existing `GetActivitiesEvent(sourceType:)`. Every subsequent stream
/// emission is turned into an `ActivityLoaded(activities: ...)` state — see
/// `ActivityBloc`'s internal `_ActivitiesUpdated` event for how.
class WatchActivitiesEvent extends ActivityEvent {
  WatchActivitiesEvent({this.sourceType});
  final String? sourceType;

  @override
  List<Object> get props => [sourceType ?? ''];
}

class AddActivityEvent extends ActivityEvent {
  AddActivityEvent(this.activity);
  final Activity activity;

  @override
  List<Object> get props => [activity];
}

class UpdateActivityEvent extends ActivityEvent {
  UpdateActivityEvent(this.activity);
  final Activity activity;

  @override
  List<Object> get props => [activity];
}

class DeleteActivityEvent extends ActivityEvent {
  DeleteActivityEvent(this.id);
  final String id;

  @override
  List<Object> get props => [id];
}
