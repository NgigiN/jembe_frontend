import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_lands.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_land.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LandBloc extends Bloc<LandEvent, LandState> {

  LandBloc({
    required this.getLands,
    required this.addLand,
    required this.updateLand,
    required this.deleteLand,
  })
    : super(LandInitial()) {
    on<GetLandsEvent>((event, emit) async {
      emit(const LandLoading());
      final result = await getLands(NoParams());
      result.fold(
        (failure) => emit(LandError(resolveFailureMessage(failure, 'Failed to load lands'))),
        (lands) => emit(LandLoaded(lands: lands)),
      );
    });

    on<AddLandEvent>((event, emit) async {
      final currentLands = state.lands;

      emit(LandLoading(lands: currentLands));
      final result = await addLand(AddLandParams(land: event.land));
      result.fold(
        (failure) => emit(LandError(
          resolveFailureMessage(failure, 'Failed to add land'),
          lands: currentLands,
        )),
        (land) {
          final updatedLands = List<Land>.from(currentLands)..add(land);
          emit(LandLoaded(lands: updatedLands, successMessage: 'Land added'));
        },
      );
    });

    on<UpdateLandEvent>((event, emit) async {
      final currentLands = state.lands;

      emit(LandLoading(lands: currentLands));
      final result = await updateLand(UpdateLandParams(land: event.land));
      result.fold(
        (failure) => emit(LandError(
          resolveFailureMessage(failure, 'Failed to update land'),
          lands: currentLands,
        )),
        (updatedLand) {
          final updatedLands = currentLands.map((land) {
            return land.id == updatedLand.id ? updatedLand : land;
          }).toList();
          emit(LandLoaded(lands: updatedLands, successMessage: 'Land updated'));
        },
      );
    });

    on<DeleteLandEvent>((event, emit) async {
      final currentLands = state.lands;

      emit(LandLoading(lands: currentLands));
      final result = await deleteLand(DeleteLandParams(id: event.id));
      result.fold(
        (failure) => emit(LandError(
          resolveFailureMessage(failure, 'Failed to delete land'),
          lands: currentLands,
        )),
        (_) {
          final updatedLands =
              currentLands.where((land) => land.id != event.id).toList();
          emit(LandLoaded(lands: updatedLands, successMessage: 'Land deleted'));
        },
      );
    });
  }
  final GetLands getLands;
  final AddLand addLand;
  final UpdateLand updateLand;
  final DeleteLand deleteLand;
}
