import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/land.dart';
import '../../domain/usecases/get_lands.dart';
import '../../domain/usecases/add_land.dart';
import '../../domain/usecases/update_land.dart';
import '../../domain/usecases/delete_land.dart';
import '../bloc/land_event.dart';
import '../bloc/land_state.dart';

class LandBloc extends Bloc<LandEvent, LandState> {
  final GetLands getLands;
  final AddLand addLand;
  final UpdateLand updateLand;
  final DeleteLand deleteLand;

  LandBloc({
    required this.getLands,
    required this.addLand,
    required this.updateLand,
    required this.deleteLand,
  })
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
      final currentLands = state is LandLoaded
          ? (state as LandLoaded).lands
          : <Land>[];

      emit(LandLoading());
      final result = await addLand(AddLandParams(land: event.land));
      result.fold(
        (failure) {
          String message = 'Failed to add land';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(LandError(message, lands: currentLands));
        },
        (land) {
          final updatedLands = List<Land>.from(currentLands)..add(land);
          emit(LandLoaded(lands: updatedLands));
        },
      );
    });

    on<UpdateLandEvent>((event, emit) async {
      final currentLands = state is LandLoaded
          ? (state as LandLoaded).lands
          : <Land>[];

      emit(LandLoading());
      final result = await updateLand(UpdateLandParams(land: event.land));
      result.fold(
        (failure) {
          String message = 'Failed to update land';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(LandError(message, lands: currentLands));
        },
        (updatedLand) {
          final updatedLands = currentLands.map((land) {
            return land.id == updatedLand.id ? updatedLand : land;
          }).toList();
          emit(LandLoaded(lands: updatedLands));
        },
      );
    });

    on<DeleteLandEvent>((event, emit) async {
      final currentLands = state is LandLoaded
          ? (state as LandLoaded).lands
          : <Land>[];

      emit(LandLoading());
      final result = await deleteLand(DeleteLandParams(id: event.id));
      result.fold(
        (failure) {
          String message = 'Failed to delete land';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(LandError(message, lands: currentLands));
        },
        (_) {
          final updatedLands =
              currentLands.where((land) => land.id != event.id).toList();
          emit(LandLoaded(lands: updatedLands));
        },
      );
    });
  }
}
