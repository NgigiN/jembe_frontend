import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/land.dart';
import '../../domain/entities/plant.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/input.dart';
import '../../domain/usecases/add_land.dart';
import '../../domain/usecases/get_lands.dart';
import '../../domain/usecases/update_land.dart';
import '../../domain/usecases/delete_land.dart';
import '../../domain/usecases/add_plant.dart';
import '../../domain/usecases/get_plants.dart';
import '../../domain/usecases/update_plant.dart';
import '../../domain/usecases/delete_plant.dart';
import '../../domain/usecases/add_season.dart';
import '../../domain/usecases/get_seasons.dart';
import '../../domain/usecases/update_season.dart';
import '../../domain/usecases/delete_season.dart';
import '../../domain/usecases/add_activity.dart';
import '../../domain/usecases/get_activities.dart';
import '../../domain/usecases/update_activity.dart';
import '../../domain/usecases/delete_activity.dart';
import '../../domain/usecases/add_input.dart';
import '../../domain/usecases/get_inputs.dart';
import '../../domain/usecases/update_input.dart';
import '../../domain/usecases/delete_input.dart';
import '../../../auth/data/utils/user_utils.dart';

import 'farm_event.dart';
import 'farm_state.dart';

class FarmBloc extends Bloc<FarmEvent, FarmState> {
  final GetLands getLands;
  final AddLand addLand;
  final UpdateLand updateLand;
  final DeleteLand deleteLand;
  final GetPlants getPlants;
  final AddPlant addPlant;
  final UpdatePlant updatePlant;
  final DeletePlant deletePlant;
  final GetSeasons getSeasons;
  final AddSeason addSeason;
  final UpdateSeason updateSeason;
  final DeleteSeason deleteSeason;
  final GetActivities getActivities;
  final AddActivity addActivity;
  final UpdateActivity updateActivity;
  final DeleteActivity deleteActivity;
  final GetInputs getInputs;
  final AddInput addInput;
  final UpdateInput updateInput;
  final DeleteInput deleteInput;

  FarmBloc({
    required this.getLands,
    required this.addLand,
    required this.updateLand,
    required this.deleteLand,
    required this.getPlants,
    required this.addPlant,
    required this.updatePlant,
    required this.deletePlant,
    required this.getSeasons,
    required this.addSeason,
    required this.updateSeason,
    required this.deleteSeason,
    required this.getActivities,
    required this.addActivity,
    required this.updateActivity,
    required this.deleteActivity,
    required this.getInputs,
    required this.addInput,
    required this.updateInput,
    required this.deleteInput,
  }) : super(FarmInitial()) {
    on<GetLandsEvent>((event, emit) async {
      emit(FarmLoading());
      final result = await getLands(NoParams());
      result.fold(
        (failure) => emit(FarmError('Failed to load lands')),
        (lands) => emit(
          FarmLoaded(
            lands: lands,
            plants: state.plants,
            seasons: state.seasons,
            activities: state.activities,
            inputs: state.inputs,
          ),
        ),
      );
    });

    on<AddLandEvent>((event, emit) async {
      // Capture current state BEFORE emitting FarmLoading
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      // Get current user ID
      final userId = await UserUtils.getCurrentUserId();
      if (userId == null) {
        emit(FarmError('User not authenticated'));
        return;
      }

      // Create a Land object from the event parameters
      final land = Land(
        id: '', // Will be set by the server
        userId: userId,
        name: event.name,
        size: double.tryParse(event.size),
        location: event.location.isEmpty ? null : event.location,
        soilType: event.soilType.isEmpty ? null : event.soilType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await addLand(AddLandParams(land: land));
      result.fold((failure) => emit(FarmError('Failed to add land')), (
        newLand,
      ) {
        final updatedLands = List<Land>.from(currentLands)..add(newLand);

        emit(
          FarmLoaded(
            lands: updatedLands,
            plants: currentPlants,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    // Plant event handlers
    on<GetPlantsEvent>((event, emit) async {
      emit(FarmLoading());
      final result = await getPlants(NoParams());
      result.fold(
        (failure) => emit(FarmError('Failed to load plants')),
        (plants) => emit(
          FarmLoaded(
            lands: state.lands,
            plants: plants,
            seasons: state.seasons,
            activities: state.activities,
            inputs: state.inputs,
          ),
        ),
      );
    });

    on<AddPlantEvent>((event, emit) async {
      // Capture current state BEFORE emitting FarmLoading
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      // Get current user ID
      final userId = await UserUtils.getCurrentUserId();
      if (userId == null) {
        emit(FarmError('User not authenticated'));
        return;
      }

      // Create a Plant object from the event parameters
      final plant = Plant(
        id: '',
        userId: userId,
        name: event.name,
        variety: event.variety,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await addPlant(AddPlantParams(plant: plant));
      result.fold((failure) => emit(FarmError('Failed to add plant')), (
        newPlant,
      ) {
        final updatedPlants = List<Plant>.from(currentPlants)..add(newPlant);

        emit(
          FarmLoaded(
            lands: currentLands,
            plants: updatedPlants,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    // Season event handlers
    on<GetSeasonsEvent>((event, emit) async {
      emit(FarmLoading());
      final result = await getSeasons(NoParams());
      result.fold(
        (failure) => emit(FarmError('Failed to load seasons')),
        (seasons) => emit(
          FarmLoaded(
            lands: state.lands,
            plants: state.plants,
            seasons: seasons,
            activities: state.activities,
            inputs: state.inputs,
          ),
        ),
      );
    });

    on<AddSeasonEvent>((event, emit) async {
      // Capture current state BEFORE emitting FarmLoading
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      // Get current user ID
      final userId = await UserUtils.getCurrentUserId();
      if (userId == null) {
        emit(FarmError('User not authenticated'));
        return;
      }

      // Create a Season object from the event parameters
      final season = Season(
        id: '', // Will be set by the server
        userId: userId,
        name: event.name,
        landId: event.landId,
        plantId: event.plantId,
        startDate: DateTime.parse(event.startDate),
        endDate: event.endDate.isNotEmpty
            ? DateTime.parse(event.endDate)
            : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await addSeason(AddSeasonParams(season: season));
      result.fold((failure) => emit(FarmError('Failed to add season')), (
        newSeason,
      ) {
        final updatedSeasons = List<Season>.from(currentSeasons)
          ..add(newSeason);

        emit(
          FarmLoaded(
            lands: currentLands,
            plants: currentPlants,
            seasons: updatedSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    // Activity event handlers
    on<GetActivitiesEvent>((event, emit) async {
      emit(FarmLoading());
      final result = await getActivities(NoParams());
      result.fold(
        (failure) => emit(FarmError('Failed to load activities')),
        (activities) => emit(
          FarmLoaded(
            lands: state.lands,
            plants: state.plants,
            seasons: state.seasons,
            activities: activities,
            inputs: state.inputs,
          ),
        ),
      );
    });

    on<AddActivityEvent>((event, emit) async {
      // Capture current state BEFORE emitting FarmLoading
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      // Create an Activity object from the event parameters
      final activity = Activity(
        id: '',
        sourceType: event.sourceType,
        sourceId: event.sourceId,
        animalId: event.animalId,
        type: event.type,
        date: DateTime.parse(event.date),
        cost: event.cost,
        details: event.details,
        notes: event.notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await addActivity(AddActivityParams(activity: activity));
      result.fold((failure) => emit(FarmError('Failed to add activity')), (
        newActivity,
      ) {
        final updatedActivities = List<Activity>.from(currentActivities)
          ..add(newActivity);

        emit(
          FarmLoaded(
            lands: currentLands,
            plants: currentPlants,
            seasons: currentSeasons,
            activities: updatedActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    // Input event handlers
    on<GetInputsEvent>((event, emit) async {
      emit(FarmLoading());
      final result = await getInputs(NoParams());
      result.fold(
        (failure) => emit(FarmError('Failed to load inputs')),
        (inputs) => emit(
          FarmLoaded(
            lands: state.lands,
            plants: state.plants,
            seasons: state.seasons,
            activities: state.activities,
            inputs: inputs,
          ),
        ),
      );
    });

    on<AddInputEvent>((event, emit) async {
      // Capture current state BEFORE emitting FarmLoading
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      // Get current user ID
      final userId = await UserUtils.getCurrentUserId();
      if (userId == null) {
        emit(FarmError('User not authenticated'));
        return;
      }

      // Create an Input object from the event parameters
      final input = Input(
        id: '',
        sourceType: event.sourceType,
        sourceId: event.sourceId,
        animalId: event.animalId,
        type: event.type,
        quantity: event.quantity,
        cost: event.cost,
        date: DateTime.parse(event.date),
        notes: event.notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await addInput(AddInputParams(input: input));
      result.fold((failure) => emit(FarmError('Failed to add input')), (
        newInput,
      ) {
        final updatedInputs = List<Input>.from(currentInputs)..add(newInput);

        emit(
          FarmLoaded(
            lands: currentLands,
            plants: currentPlants,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: updatedInputs,
          ),
        );
      });
    });

    // Update event handlers
    on<UpdateLandEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final land = Land(
        id: event.id,
        userId: currentLands.firstWhere((l) => l.id == event.id).userId,
        name: event.name,
        size: double.tryParse(event.size),
        location: event.location.isEmpty ? null : event.location,
        soilType: event.soilType.isEmpty ? null : event.soilType,
        createdAt: currentLands.firstWhere((l) => l.id == event.id).createdAt,
        updatedAt: DateTime.now(),
      );

      final result = await updateLand(UpdateLandParams(land: land));
      result.fold((failure) => emit(FarmError('Failed to update land')), (
        updatedLand,
      ) {
        final updatedLands = currentLands
            .map((l) => l.id == event.id ? updatedLand : l)
            .toList();
        emit(
          FarmLoaded(
            lands: updatedLands,
            plants: currentPlants,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    on<DeleteLandEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final result = await deleteLand(DeleteLandParams(id: event.id));
      result.fold((failure) => emit(FarmError('Failed to delete land')), (_) {
        final updatedLands = currentLands
            .where((l) => l.id != event.id)
            .toList();
        emit(
          FarmLoaded(
            lands: updatedLands,
            plants: currentPlants,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    on<UpdatePlantEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final plant = Plant(
        id: event.id,
        userId: currentPlants.firstWhere((p) => p.id == event.id).userId,
        name: event.name,
        variety: event.variety.isEmpty ? null : event.variety,
        createdAt: currentPlants.firstWhere((p) => p.id == event.id).createdAt,
        updatedAt: DateTime.now(),
      );

      final result = await updatePlant(UpdatePlantParams(plant: plant));
      result.fold((failure) => emit(FarmError('Failed to update plant')), (
        updatedPlant,
      ) {
        final updatedPlants = currentPlants
            .map((p) => p.id == event.id ? updatedPlant : p)
            .toList();
        emit(
          FarmLoaded(
            lands: currentLands,
            plants: updatedPlants,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    on<DeletePlantEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final result = await deletePlant(DeletePlantParams(id: event.id));
      result.fold((failure) => emit(FarmError('Failed to delete plant')), (_) {
        final updatedPlants = currentPlants
            .where((p) => p.id != event.id)
            .toList();
        emit(
          FarmLoaded(
            lands: currentLands,
            plants: updatedPlants,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    on<UpdateSeasonEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final season = Season(
        id: event.id,
        userId: currentSeasons.firstWhere((s) => s.id == event.id).userId,
        name: event.name,
        landId: event.landId,
        plantId: event.plantId,
        startDate: DateTime.parse(event.startDate),
        endDate: event.endDate.isNotEmpty
            ? DateTime.parse(event.endDate)
            : null,
        createdAt: currentSeasons.firstWhere((s) => s.id == event.id).createdAt,
        updatedAt: DateTime.now(),
      );

      final result = await updateSeason(UpdateSeasonParams(season: season));
      result.fold((failure) => emit(FarmError('Failed to update season')), (
        updatedSeason,
      ) {
        final updatedSeasons = currentSeasons
            .map((s) => s.id == event.id ? updatedSeason : s)
            .toList();
        emit(
          FarmLoaded(
            lands: currentLands,
            plants: currentPlants,
            seasons: updatedSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    on<DeleteSeasonEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final result = await deleteSeason(DeleteSeasonParams(id: event.id));
      result.fold((failure) => emit(FarmError('Failed to delete season')), (_) {
        final updatedSeasons = currentSeasons
            .where((s) => s.id != event.id)
            .toList();
        emit(
          FarmLoaded(
            lands: currentLands,
            plants: currentPlants,
            seasons: updatedSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    on<UpdateActivityEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final activity = Activity(
        id: event.id,
        sourceType: event.sourceType,
        sourceId: event.sourceId,
        animalId: event.animalId,
        type: event.type,
        date: DateTime.parse(event.date),
        cost: event.cost,
        details: event.details,
        notes: event.notes,
        createdAt: currentActivities
            .firstWhere((a) => a.id == event.id)
            .createdAt,
        updatedAt: DateTime.now(),
      );

      final result = await updateActivity(
        UpdateActivityParams(activity: activity),
      );
      result.fold((failure) => emit(FarmError('Failed to update activity')), (
        updatedActivity,
      ) {
        final updatedActivities = currentActivities
            .map((a) => a.id == event.id ? updatedActivity : a)
            .toList();
        emit(
          FarmLoaded(
            lands: currentLands,
            plants: currentPlants,
            seasons: currentSeasons,
            activities: updatedActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    on<DeleteActivityEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final result = await deleteActivity(DeleteActivityParams(id: event.id));
      result.fold((failure) => emit(FarmError('Failed to delete activity')), (
        _,
      ) {
        final updatedActivities = currentActivities
            .where((a) => a.id != event.id)
            .toList();
        emit(
          FarmLoaded(
            lands: currentLands,
            plants: currentPlants,
            seasons: currentSeasons,
            activities: updatedActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    on<UpdateInputEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final input = Input(
        id: event.id,
        sourceType: event.sourceType,
        sourceId: event.sourceId,
        animalId: event.animalId,
        type: event.type,
        quantity: event.quantity,
        cost: event.cost,
        date: DateTime.parse(event.date),
        notes: event.notes,
        createdAt: currentInputs.firstWhere((i) => i.id == event.id).createdAt,
        updatedAt: DateTime.now(),
      );

      final result = await updateInput(UpdateInputParams(input: input));
      result.fold((failure) => emit(FarmError('Failed to update input')), (
        updatedInput,
      ) {
        final updatedInputs = currentInputs
            .map((i) => i.id == event.id ? updatedInput : i)
            .toList();
        emit(
          FarmLoaded(
            lands: currentLands,
            plants: currentPlants,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: updatedInputs,
          ),
        );
      });
    });

    on<DeleteInputEvent>((event, emit) async {
      final currentState = state;
      final currentLands = currentState.lands;
      final currentPlants = currentState.plants;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      final result = await deleteInput(DeleteInputParams(id: event.id));
      result.fold((failure) => emit(FarmError('Failed to delete input')), (_) {
        final updatedInputs = currentInputs
            .where((i) => i.id != event.id)
            .toList();
        emit(
          FarmLoaded(
            lands: currentLands,
            plants: currentPlants,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: updatedInputs,
          ),
        );
      });
    });
  }
}
