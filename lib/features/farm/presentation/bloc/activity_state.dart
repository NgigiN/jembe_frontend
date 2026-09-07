import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';

abstract class ActivityState extends Equatable {
  const ActivityState({this.activities = const []});
  final List<Activity> activities;

  @override
  List<Object?> get props => [activities];
}

class ActivityInitial extends ActivityState {}

class ActivityLoading extends ActivityState {
  const ActivityLoading({super.activities});
}

class ActivityLoaded extends ActivityState {
  const ActivityLoaded({
    required super.activities,
    this.successMessage,
    this.hasReachedMax = true,
    this.nextCursor,
  });
  final String? successMessage;

  /// Online infinite-scroll (P3-02a): `false` only when the last page came
  /// back full (== `kOnlineListPageSize`), i.e. another page may exist.
  /// Defaults to `true` so the offline stream path and the Add/Update/Delete
  /// handlers (which don't page) never trigger a load-more.
  final bool hasReachedMax;

  /// The server id to page from next (`?cursor=`), i.e. the last item's id.
  /// `null` once [hasReachedMax] or when the list is empty.
  final int? nextCursor;

  @override
  List<Object?> get props => [
    activities,
    successMessage,
    hasReachedMax,
    nextCursor,
  ];
}

class ActivityError extends ActivityState {
  const ActivityError(this.message, {super.activities});
  final String message;

  @override
  List<Object> get props => [message, activities];
}
