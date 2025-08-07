import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/land.dart';
import '../../domain/usecases/get_lands.dart';
import '../../domain/usecases/add_land.dart';
import '../bloc/land_event.dart';
import '../bloc/land_state.dart';

class LandBloc extends Bloc<LandEvent, LandState> {
  final GetLands getLands;
  final AddLand addLand;

  LandBloc({required this.getLands, required this.addLand})
    : super(LandInitial()) {
    on<GetLandsEvent>((event, emit) async {
      emit(LandLoading());
      final result = await getLands(NoParams());
      result.fold(
        (failure) => emit(LandError('Failed to load lands')),
        (lands) => emit(LandLoaded(lands: lands)),
      );
    });

    on<AddLandEvent>((event, emit) async {
      emit(LandLoading());
      final result = await addLand(AddLandParams(land: event.land));
      result.fold(
        (failure) {
          String message = 'Failed to add land';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(LandError(message));
        },
        (land) {
          final currentState = state;
          if (currentState is LandLoaded) {
            final updatedLands = List<Land>.from(currentState.lands)..add(land);
            emit(LandLoaded(lands: updatedLands));
          } else {
            emit(LandLoaded(lands: [land]));
          }
        },
      );
    });
  }
}
