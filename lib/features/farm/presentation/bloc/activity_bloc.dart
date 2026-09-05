import 'dart:async';

import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_activities.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_activities_params.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_activities.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchActivitiesEvent` handler below listens to
/// `watchActivities(sourceType:)` and funnels every emission back through
/// the bloc's own event queue via `add(...)` instead of calling `emit`
/// directly from the stream callback — the standard bloc pattern for
/// turning an external stream into state, since `emit` is only valid while
/// its owning `on<...>` handler is still active.
class _ActivitiesUpdated extends ActivityEvent {
  _ActivitiesUpdated(this.activities);
  final List<Activity> activities;

  @override
  List<Object> get props => [activities];
}

/// Internal-only event: the `WatchActivitiesEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_ActivitiesUpdated` — `emit` is only valid inside an active `on<...>`
/// handler, not from a raw stream callback). Non-fatal: it surfaces an
/// `ActivityError` over the last known `activities` snapshot rather than
/// crashing the bloc or dropping reactivity — the subscription is NOT
/// cancelled, so a later emission (if the underlying stream keeps going)
/// still comes through.
class _ActivitiesWatchFailed extends ActivityEvent {
  _ActivitiesWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  ActivityBloc({
    required this.getActivities,
    required this.addActivity,
    required this.updateActivity,
    required this.deleteActivity,
    required this.watchActivities,
  }) : super(ActivityInitial()) {
    on<GetActivitiesEvent>(_onGetActivities);
    on<WatchActivitiesEvent>(_onWatchActivities);
    on<_ActivitiesUpdated>((event, emit) {
      emit(ActivityLoaded(activities: event.activities));
    });
    on<_ActivitiesWatchFailed>((event, emit) {
      emit(ActivityError(event.message, activities: state.activities));
    });
    on<AddActivityEvent>(_onAddActivity);
    on<UpdateActivityEvent>(_onUpdateActivity);
    on<DeleteActivityEvent>(_onDeleteActivity);
  }

  final GetActivities getActivities;
  final AddActivity addActivity;
  final UpdateActivity updateActivity;
  final DeleteActivity deleteActivity;
  final WatchActivities watchActivities;

  StreamSubscription<List<Activity>>? _activitiesSubscription;
  bool _watchStarted = false;

  Future<void> _onGetActivities(
    GetActivitiesEvent event,
    Emitter<ActivityState> emit,
  ) async {
    appLogger.debug(LogCategory.farm, 'GetActivitiesEvent triggered');
    emit(const ActivityLoading());

    final result = await getActivities(
      GetActivitiesParams(sourceType: event.sourceType),
    );
    result.fold(
      (failure) {
        appLogger.warning(LogCategory.farm, 'GetActivities failed: $failure');
        emit(ActivityError(resolveFailureMessage(failure, 'Failed to load activities')));
      },
      (activities) {
        appLogger.info(LogCategory.farm, 'Loaded ${activities.length} activities');
        emit(ActivityLoaded(activities: activities));
      },
    );
  }

  // Synchronous handler, no `await` before the guard: dispatching
  // WatchActivitiesEvent twice in quick succession (e.g. initState +
  // pull-to-refresh) must never race and orphan a live subscription — the
  // guard makes the second (and every subsequent) dispatch a pure no-op
  // instead.
  void _onWatchActivities(
    WatchActivitiesEvent event,
    Emitter<ActivityState> emit,
  ) {
    if (_watchStarted) return;
    _watchStarted = true;
    _activitiesSubscription = watchActivities(sourceType: event.sourceType).listen(
      (activities) => add(_ActivitiesUpdated(activities)),
      onError: (Object error, StackTrace stackTrace) {
        appLogger.logError('ActivityBloc.watchActivities', error, stackTrace);
        add(_ActivitiesWatchFailed('Live sync interrupted. Pull to refresh.'));
      },
      onDone: () {
        appLogger.info(
          LogCategory.farm,
          'ActivityBloc.watchActivities stream completed',
        );
      },
    );
  }

  Future<void> _onAddActivity(
    AddActivityEvent event,
    Emitter<ActivityState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await addActivity(
        AddActivityParams(activity: event.activity),
      );
      result.fold(
        (failure) => emit(ActivityError(
          resolveFailureMessage(failure, 'Failed to add activity'),
          activities: state.activities,
        )),
        (_) => emit(
          ActivityLoaded(
            activities: state.activities,
            successMessage: 'Activity recorded',
          ),
        ),
      );
      return;
    }

    final currentActivities = state.activities;

    emit(ActivityLoading(activities: currentActivities));
    final result = await addActivity(
      AddActivityParams(activity: event.activity),
    );
    result.fold(
      (failure) => emit(ActivityError(
        resolveFailureMessage(failure, 'Failed to add activity'),
        activities: currentActivities,
      )),
      (activity) {
        final updatedActivities = List<Activity>.from(currentActivities)
          ..add(activity);
        emit(ActivityLoaded(
          activities: updatedActivities,
          successMessage: 'Activity recorded',
        ));
      },
    );
  }

  Future<void> _onUpdateActivity(
    UpdateActivityEvent event,
    Emitter<ActivityState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await updateActivity(
        UpdateActivityParams(activity: event.activity),
      );
      result.fold(
        (failure) => emit(ActivityError(
          resolveFailureMessage(failure, 'Failed to update activity'),
          activities: state.activities,
        )),
        (_) => emit(
          ActivityLoaded(
            activities: state.activities,
            successMessage: 'Activity updated',
          ),
        ),
      );
      return;
    }

    final currentActivities = state.activities;

    emit(ActivityLoading(activities: currentActivities));
    final result = await updateActivity(
      UpdateActivityParams(activity: event.activity),
    );
    result.fold(
      (failure) => emit(ActivityError(
        resolveFailureMessage(failure, 'Failed to update activity'),
        activities: currentActivities,
      )),
      (updatedActivity) {
        final updatedActivities = currentActivities.map((activity) {
          return activity.id == updatedActivity.id
              ? updatedActivity
              : activity;
        }).toList();
        emit(ActivityLoaded(
          activities: updatedActivities,
          successMessage: 'Activity updated',
        ));
      },
    );
  }

  Future<void> _onDeleteActivity(
    DeleteActivityEvent event,
    Emitter<ActivityState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await deleteActivity(DeleteActivityParams(id: event.id));
      result.fold(
        (failure) => emit(ActivityError(
          resolveFailureMessage(failure, 'Failed to delete activity'),
          activities: state.activities,
        )),
        (_) => emit(
          ActivityLoaded(
            activities: state.activities,
            successMessage: 'Activity deleted',
          ),
        ),
      );
      return;
    }

    final currentActivities = state.activities;

    emit(ActivityLoading(activities: currentActivities));
    final result = await deleteActivity(DeleteActivityParams(id: event.id));
    result.fold(
      (failure) => emit(ActivityError(
        resolveFailureMessage(failure, 'Failed to delete activity'),
        activities: currentActivities,
      )),
      (_) {
        final updatedActivities = currentActivities
            .where((activity) => activity.id != event.id)
            .toList();
        emit(ActivityLoaded(
          activities: updatedActivities,
          successMessage: 'Activity deleted',
        ));
      },
    );
  }

  @override
  Future<void> close() async {
    await _activitiesSubscription?.cancel();
    return super.close();
  }
}
