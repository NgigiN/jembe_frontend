import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/activity.dart';
import '../../domain/usecases/get_activities.dart';
import '../../domain/usecases/get_activities_params.dart';
import '../../domain/usecases/add_activity.dart';
import '../../domain/usecases/update_activity.dart';
import '../../domain/usecases/delete_activity.dart';
import '../bloc/activity_event.dart';
import '../bloc/activity_state.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final GetActivities getActivities;
  final AddActivity addActivity;
  final UpdateActivity updateActivity;
  final DeleteActivity deleteActivity;

  ActivityBloc({
    required this.getActivities,
    required this.addActivity,
    required this.updateActivity,
    required this.deleteActivity,
  })
    : super(ActivityInitial()) {
    on<GetActivitiesEvent>((event, emit) async {
      appLogger.debug(LogCategory.farm, 'GetActivitiesEvent triggered');
      emit(ActivityLoading());

      try {
        final result = await getActivities(
          GetActivitiesParams(sourceType: event.sourceType),
        );
        result.fold(
          (failure) {
            appLogger.warning(
              LogCategory.farm,
              'GetActivities failed: $failure',
            );
            String message = 'Failed to load activities';
            if (failure is ServerFailure && failure.errorMessage != null) {
              message = failure.errorMessage!;
            }
            emit(ActivityError(message));
          },
          (activities) {
            appLogger.info(
              LogCategory.farm,
              'Loaded ${activities.length} activities',
            );
            emit(ActivityLoaded(activities: activities));
          },
        );
      } catch (e) {
        appLogger.error(LogCategory.farm, 'GetActivities exception', e);
        emit(ActivityError('Unexpected error: $e'));
      }
    });

    on<AddActivityEvent>((event, emit) async {
      // Store current activities before emitting loading state
      final currentActivities = state is ActivityLoaded
          ? (state as ActivityLoaded).activities
          : <Activity>[];

      emit(ActivityLoading());
      final result = await addActivity(
        AddActivityParams(activity: event.activity),
      );
      result.fold(
        (failure) {
          String message = 'Failed to add activity';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(ActivityError(message));
        },
        (activity) {
          final updatedActivities = List<Activity>.from(currentActivities)
            ..add(activity);
          emit(ActivityLoaded(activities: updatedActivities));
        },
      );
    });

    on<UpdateActivityEvent>((event, emit) async {
      final currentActivities = state is ActivityLoaded
          ? (state as ActivityLoaded).activities
          : <Activity>[];

      emit(ActivityLoading());
      final result = await updateActivity(
        UpdateActivityParams(activity: event.activity),
      );
      result.fold(
        (failure) {
          String message = 'Failed to update activity';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(ActivityError(message, activities: currentActivities));
        },
        (updatedActivity) {
          final updatedActivities = currentActivities.map((activity) {
            return activity.id == updatedActivity.id
                ? updatedActivity
                : activity;
          }).toList();
          emit(ActivityLoaded(activities: updatedActivities));
        },
      );
    });

    on<DeleteActivityEvent>((event, emit) async {
      final currentActivities = state is ActivityLoaded
          ? (state as ActivityLoaded).activities
          : <Activity>[];

      emit(ActivityLoading());
      final result = await deleteActivity(DeleteActivityParams(id: event.id));
      result.fold(
        (failure) {
          String message = 'Failed to delete activity';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(ActivityError(message, activities: currentActivities));
        },
        (_) {
          final updatedActivities = currentActivities
              .where((activity) => activity.id != event.id)
              .toList();
          emit(ActivityLoaded(activities: updatedActivities));
        },
      );
    });
  }
}
