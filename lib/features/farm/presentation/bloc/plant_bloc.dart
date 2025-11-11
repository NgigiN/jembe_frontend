import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/plant.dart';
import '../../domain/usecases/get_plants.dart';
import '../../domain/usecases/add_plant.dart';
import '../bloc/plant_event.dart';
import '../bloc/plant_state.dart';

class PlantBloc extends Bloc<PlantEvent, PlantState> {
  final GetPlants getPlants;
  final AddPlant addPlant;

  PlantBloc({required this.getPlants, required this.addPlant})
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
      emit(PlantLoading());
      final result = await addPlant(AddPlantParams(plant: event.plant));
      result.fold(
        (failure) {
          String message = 'Failed to add plant';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(PlantError(message));
        },
        (plant) {
          final currentState = state;
          if (currentState is PlantLoaded) {
            final updatedPlants = List<Plant>.from(currentState.plants)
              ..add(plant);
            emit(PlantLoaded(plants: updatedPlants));
          } else {
            emit(PlantLoaded(plants: [plant]));
          }
        },
      );
    });
  }
}
