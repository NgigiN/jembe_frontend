import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/activity.dart';
import '../../domain/usecases/get_activities.dart';
import '../../domain/usecases/add_activity.dart';
import '../bloc/activity_event.dart';
import '../bloc/activity_state.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final GetActivities getActivities;
  final AddActivity addActivity;

  ActivityBloc({required this.getActivities, required this.addActivity})
    : super(ActivityInitial()) {
    on<GetActivitiesEvent>((event, emit) async {
      print('GetActivitiesEvent triggered');
      emit(ActivityLoading());

      try {
        final result = await getActivities(NoParams());
        result.fold(
          (failure) {
            print('GetActivities failed: $failure');
            String message = 'Failed to load activities';
            if (failure is ServerFailure && failure.errorMessage != null) {
              message = failure.errorMessage!;
            }
            emit(ActivityError(message));
          },
          (activities) {
            print(
              'GetActivities success: ${activities.length} activities loaded',
            );
            emit(ActivityLoaded(activities: activities));
          },
        );
      } catch (e) {
        print('GetActivities exception: $e');
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
  }
}
