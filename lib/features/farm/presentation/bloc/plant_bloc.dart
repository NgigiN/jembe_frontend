import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/plant.dart';
import '../../domain/usecases/get_plants.dart';
import '../../domain/usecases/add_plant.dart';
import '../../domain/usecases/update_plant.dart';
import '../../domain/usecases/delete_plant.dart';
import '../bloc/plant_event.dart';
import '../bloc/plant_state.dart';

class PlantBloc extends Bloc<PlantEvent, PlantState> {
  final GetPlants getPlants;
  final AddPlant addPlant;
  final UpdatePlant updatePlant;
  final DeletePlant deletePlant;

  PlantBloc({
    required this.getPlants,
    required this.addPlant,
    required this.updatePlant,
    required this.deletePlant,
  })
    : super(PlantInitial()) {
    on<GetPlantsEvent>((event, emit) async {
      emit(PlantLoading());
      final result = await getPlants(NoParams());
      result.fold(
        (failure) => emit(PlantError('Failed to load plants')),
        (plants) => emit(PlantLoaded(plants: plants)),
      );
    });

    on<AddPlantEvent>((event, emit) async {
      final currentPlants = state is PlantLoaded
          ? (state as PlantLoaded).plants
          : <Plant>[];

      emit(PlantLoading());
      final result = await addPlant(AddPlantParams(plant: event.plant));
      result.fold(
        (failure) {
          String message = 'Failed to add plant';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(PlantError(message, plants: currentPlants));
        },
        (plant) {
          final updatedPlants = List<Plant>.from(currentPlants)..add(plant);
          emit(PlantLoaded(plants: updatedPlants));
        },
      );
    });

    on<UpdatePlantEvent>((event, emit) async {
      final currentPlants = state is PlantLoaded
          ? (state as PlantLoaded).plants
          : <Plant>[];

      emit(PlantLoading());
      final result = await updatePlant(UpdatePlantParams(plant: event.plant));
      result.fold(
        (failure) {
          String message = 'Failed to update plant';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(PlantError(message, plants: currentPlants));
        },
        (updatedPlant) {
          final updatedPlants = currentPlants.map((plant) {
            return plant.id == updatedPlant.id ? updatedPlant : plant;
          }).toList();
          emit(PlantLoaded(plants: updatedPlants));
        },
      );
    });

    on<DeletePlantEvent>((event, emit) async {
      final currentPlants = state is PlantLoaded
          ? (state as PlantLoaded).plants
          : <Plant>[];

      emit(PlantLoading());
      final result = await deletePlant(DeletePlantParams(id: event.id));
      result.fold(
        (failure) {
          String message = 'Failed to delete plant';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(PlantError(message, plants: currentPlants));
        },
        (_) {
          final updatedPlants =
              currentPlants.where((plant) => plant.id != event.id).toList();
          emit(PlantLoaded(plants: updatedPlants));
        },
      );
    });
  }
}
