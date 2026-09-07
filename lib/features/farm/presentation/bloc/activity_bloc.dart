import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';
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
  ActivityBloc({required this.repository}) : super(ActivityInitial()) {
    on<GetActivitiesEvent>(_onGetActivities);
    on<LoadMoreActivitiesEvent>(_onLoadMoreActivities);
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

  final ActivityRepository repository;

  StreamSubscription<List<Activity>>? _activitiesSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMoreActivitiesEvent]: guards against a second
  /// page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  Future<void> _onGetActivities(
    GetActivitiesEvent event,
    Emitter<ActivityState> emit,
  ) async {
    appLogger.debug(LogCategory.farm, 'GetActivitiesEvent triggered');
    emit(const ActivityLoading());

    final result = await repository.getActivities(sourceType: event.sourceType);
    result.fold(
      (failure) {
        appLogger.warning(LogCategory.farm, 'GetActivities failed: $failure');
        emit(ActivityError(resolveFailureMessage(failure, 'Failed to load activities')));
      },
      (activities) {
        appLogger.info(LogCategory.farm, 'Loaded ${activities.length} activities');
        // Online (flag off): this was page 1 of a cursor-paged list. Offline
        // returns the whole local mirror in one shot, so it always reaches
        // max here and never pages.
        final online = !OfflineConfig.enabled;
        emit(ActivityLoaded(
          activities: activities,
          hasReachedMax:
              !online || activities.length < kOnlineListPageSize,
          nextCursor: online ? _cursorOf(activities) : null,
        ));
      },
    );
  }

  /// Fetches and APPENDS the next online page. No-op when offline, when the
  /// current loaded page already reached max, when there is no cursor to page
  /// from, or when a load-more is already running.
  Future<void> _onLoadMoreActivities(
    LoadMoreActivitiesEvent event,
    Emitter<ActivityState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! ActivityLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getActivities(
        sourceType: event.sourceType,
        cursor: current.nextCursor,
      );
      result.fold(
        (failure) => emit(ActivityError(
          resolveFailureMessage(failure, 'Failed to load activities'),
          activities: current.activities,
        )),
        (more) {
          final combined = List<Activity>.from(current.activities)
            ..addAll(more);
          emit(ActivityLoaded(
            activities: combined,
            hasReachedMax: more.length < kOnlineListPageSize,
            nextCursor: _cursorOf(more),
          ));
        },
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  /// The next `?cursor=` value — the last (oldest, since the list is
  /// newest-first) item's server id, or `null` when the page is empty.
  int? _cursorOf(List<Activity> activities) =>
      activities.isEmpty ? null : int.tryParse(activities.last.id);

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
    _activitiesSubscription = repository.watchActivities(sourceType: event.sourceType).listen(
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
      final result = await repository.addActivity(event.activity);
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
    final result = await repository.addActivity(event.activity);
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
      final result = await repository.updateActivity(event.activity);
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
    final result = await repository.updateActivity(event.activity);
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
      final result = await repository.deleteActivity(event.id);
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
    final result = await repository.deleteActivity(event.id);
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
