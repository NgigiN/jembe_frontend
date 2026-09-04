import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_plants.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_plant.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlantBloc extends Bloc<PlantEvent, PlantState> {

  PlantBloc({
    required this.getPlants,
    required this.addPlant,
    required this.updatePlant,
    required this.deletePlant,
  })
    : super(PlantInitial()) {
    on<GetPlantsEvent>((event, emit) async {
      emit(const PlantLoading());
      final result = await getPlants(NoParams());
      result.fold(
        (failure) => emit(PlantError(resolveFailureMessage(failure, 'Failed to load crops'))),
        (plants) => emit(PlantLoaded(plants: plants)),
      );
    });

    on<AddPlantEvent>((event, emit) async {
      final currentPlants = state.plants;

      emit(PlantLoading(plants: currentPlants));
      final result = await addPlant(AddPlantParams(plant: event.plant));
      result.fold(
        (failure) => emit(PlantError(
          resolveFailureMessage(failure, 'Failed to add crop'),
          plants: currentPlants,
        )),
        (plant) {
          final updatedPlants = List<Plant>.from(currentPlants)..add(plant);
          emit(PlantLoaded(plants: updatedPlants, successMessage: 'Crop added'));
        },
      );
    });

    on<UpdatePlantEvent>((event, emit) async {
      final currentPlants = state.plants;

      emit(PlantLoading(plants: currentPlants));
      final result = await updatePlant(UpdatePlantParams(plant: event.plant));
      result.fold(
        (failure) => emit(PlantError(
          resolveFailureMessage(failure, 'Failed to update crop'),
          plants: currentPlants,
        )),
        (updatedPlant) {
          final updatedPlants = currentPlants.map((plant) {
            return plant.id == updatedPlant.id ? updatedPlant : plant;
          }).toList();
          emit(PlantLoaded(plants: updatedPlants, successMessage: 'Crop updated'));
        },
      );
    });

    on<DeletePlantEvent>((event, emit) async {
      final currentPlants = state.plants;

      emit(PlantLoading(plants: currentPlants));
      final result = await deletePlant(DeletePlantParams(id: event.id));
      result.fold(
        (failure) => emit(PlantError(
          resolveFailureMessage(failure, 'Failed to delete crop'),
          plants: currentPlants,
        )),
        (_) {
          final updatedPlants =
              currentPlants.where((plant) => plant.id != event.id).toList();
          emit(PlantLoaded(plants: updatedPlants, successMessage: 'Crop deleted'));
        },
      );
    });
  }
  final GetPlants getPlants;
  final AddPlant addPlant;
  final UpdatePlant updatePlant;
  final DeletePlant deletePlant;
}
