import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/land.dart';
import '../../domain/entities/crop.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/input.dart';
import '../../domain/usecases/add_land.dart';
import '../../domain/usecases/get_lands.dart';
import '../../domain/usecases/update_land.dart';
import '../../domain/usecases/add_crop.dart';
import '../../domain/usecases/get_crops.dart';
import '../../domain/usecases/add_season.dart';
import '../../domain/usecases/get_seasons.dart';
import '../../domain/usecases/add_activity.dart';
import '../../domain/usecases/get_activities.dart';
import '../../domain/usecases/add_input.dart';
import '../../domain/usecases/get_inputs.dart';
import '../../../auth/data/utils/user_utils.dart';

import 'farm_event.dart';
import 'farm_state.dart';

class FarmBloc extends Bloc<FarmEvent, FarmState> {
  final GetLands getLands;
  final AddLand addLand;
  final UpdateLand updateLand;
  final GetCrops getCrops;
  final AddCrop addCrop;
  final GetSeasons getSeasons;
  final AddSeason addSeason;
  final GetActivities getActivities;
  final AddActivity addActivity;
  final GetInputs getInputs;
  final AddInput addInput;

  FarmBloc({
    required this.getLands,
    required this.addLand,
    required this.updateLand,
    required this.getCrops,
    required this.addCrop,
    required this.getSeasons,
    required this.addSeason,
    required this.getActivities,
    required this.addActivity,
    required this.getInputs,
    required this.addInput,
  }) : super(FarmInitial()) {
    on<GetLandsEvent>((event, emit) async {
      emit(FarmLoading());
      final result = await getLands(NoParams());
      result.fold(
        (failure) => emit(FarmError('Failed to load lands')),
        (lands) => emit(
          FarmLoaded(
            lands: lands,
            crops: state.crops,
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
      final currentCrops = currentState.crops;
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
            crops: currentCrops,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: currentInputs,
          ),
        );
      });
    });

    on<UpdateLandEvent>((event, emit) async {
      emit(FarmLoading());
      final result = await updateLand(
        UpdateLandParams(id: event.id, name: event.name),
      );
      result.fold((failure) => emit(FarmError('Failed to update land')), (
        land,
      ) {
        final updatedLands = state.lands
            .map((l) => l.id == land.id ? land : l)
            .toList();
        emit(
          FarmLoaded(
            lands: updatedLands,
            crops: state.crops,
            seasons: state.seasons,
            activities: state.activities,
            inputs: state.inputs,
          ),
        );
      });
    });

    // Crop event handlers
    on<GetCropsEvent>((event, emit) async {
      emit(FarmLoading());
      final result = await getCrops(NoParams());
      result.fold(
        (failure) => emit(FarmError('Failed to load crops')),
        (crops) => emit(
          FarmLoaded(
            lands: state.lands,
            crops: crops,
            seasons: state.seasons,
            activities: state.activities,
            inputs: state.inputs,
          ),
        ),
      );
    });

    on<AddCropEvent>((event, emit) async {
      // Capture current state BEFORE emitting FarmLoading
      final currentState = state;
      final currentLands = currentState.lands;
      final currentCrops = currentState.crops;
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

      // Create a Crop object from the event parameters
      final crop = Crop(
        id: '', // Will be set by the server
        userId: userId,
        name: event.name,
        variety: event.variety,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await addCrop(AddCropParams(crop: crop));
      result.fold((failure) => emit(FarmError('Failed to add crop')), (
        newCrop,
      ) {
        final updatedCrops = List<Crop>.from(currentCrops)..add(newCrop);

        emit(
          FarmLoaded(
            lands: currentLands,
            crops: updatedCrops,
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
            crops: state.crops,
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
      final currentCrops = currentState.crops;
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
        cropId: event.cropId,
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
            crops: currentCrops,
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
            crops: state.crops,
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
      final currentCrops = currentState.crops;
      final currentSeasons = currentState.seasons;
      final currentActivities = currentState.activities;
      final currentInputs = currentState.inputs;

      emit(FarmLoading());

      // Create an Activity object from the event parameters
      final activity = Activity(
        id: '', // Will be set by the server
        seasonId: event.seasonId,
        type: event.type,
        date: DateTime.parse(event.date),
        cost: 0.0, // Default cost, can be updated later
        details: event.details,
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
            crops: currentCrops,
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
            crops: state.crops,
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
      final currentCrops = currentState.crops;
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
        id: '', // Will be set by the server
        seasonId: event.seasonId,
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
            crops: currentCrops,
            seasons: currentSeasons,
            activities: currentActivities,
            inputs: updatedInputs,
          ),
        );
      });
    });
  }
}
