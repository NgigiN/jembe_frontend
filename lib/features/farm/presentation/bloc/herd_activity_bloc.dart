import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_herd_activity.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_state.dart';

class HerdActivityBloc extends Bloc<HerdActivityEvent, HerdActivityState> {
  HerdActivityBloc({required this.addHerdActivity}) : super(HerdActivityInitial()) {
    on<AddHerdActivityEvent>(_onAddHerdActivity);
  }

  final AddHerdActivity addHerdActivity;

  Future<void> _onAddHerdActivity(
    AddHerdActivityEvent event,
    Emitter<HerdActivityState> emit,
  ) async {
    emit(HerdActivityLoading());
    final result = await addHerdActivity(
      event.herdId,
      event.activityType,
      event.count,
      event.date,
      event.notes,
    );
    result.fold(
      (failure) => emit(HerdActivityError(resolveFailureMessage(failure, 'Failed to record activity'))),
      (_) {
        final typeLabel = event.activityType == 'birth' ? 'Birth' : 'Fatality';
        emit(HerdActivitySuccess('$typeLabel recorded successfully'));
      },
    );
  }
}
