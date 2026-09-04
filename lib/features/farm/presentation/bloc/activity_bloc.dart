import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_activities.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_activities_params.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_activity.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  ActivityBloc({
    required this.getActivities,
    required this.addActivity,
    required this.updateActivity,
    required this.deleteActivity,
  }) : super(ActivityInitial()) {
    on<GetActivitiesEvent>((event, emit) async {
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
    });

    on<AddActivityEvent>((event, emit) async {
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
    });

    on<UpdateActivityEvent>((event, emit) async {
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
    });

    on<DeleteActivityEvent>((event, emit) async {
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
    });
  }
  final GetActivities getActivities;
  final AddActivity addActivity;
  final UpdateActivity updateActivity;
  final DeleteActivity deleteActivity;
}
