import 'dart:async';

import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_animals.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_animals.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchAnimalsEvent` handler below listens to `watchAnimals()` and funnels
/// every emission back through the bloc's own event queue via `add(...)`
/// instead of calling `emit` directly from the stream callback — the
/// standard bloc pattern for turning an external stream into state, since
/// `emit` is only valid while its owning `on<...>` handler is still active.
class _AnimalsUpdated extends AnimalEvent {
  _AnimalsUpdated(this.animals);
  final List<Animal> animals;

  @override
  List<Object> get props => [animals];
}

/// Internal-only event: the `WatchAnimalsEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_AnimalsUpdated` — `emit` is only valid inside an active `on<...>`
/// handler, not from a raw stream callback). Non-fatal: it surfaces an
/// `AnimalError` over the last known `animals` snapshot rather than
/// crashing the bloc or dropping reactivity — the subscription is NOT
/// cancelled, so a later emission (if the underlying stream keeps going)
/// still comes through.
class _AnimalsWatchFailed extends AnimalEvent {
  _AnimalsWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class AnimalBloc extends Bloc<AnimalEvent, AnimalState> {
  AnimalBloc({
    required this.getAnimals,
    required this.addAnimal,
    required this.updateAnimal,
    required this.deleteAnimal,
    required this.watchAnimals,
  }) : super(AnimalInitial()) {
    on<GetAnimalsEvent>((event, emit) async {
      emit(const AnimalLoading());
      final result = await getAnimals(NoParams());
      result.fold(
        (failure) => emit(
          AnimalError(resolveFailureMessage(failure, 'Failed to load animals')),
        ),
        (animals) => emit(AnimalLoaded(animals: animals)),
      );
    });

    on<WatchAnimalsEvent>((event, emit) {
      // Synchronous handler, no `await` before the guard: dispatching
      // WatchAnimalsEvent twice in quick succession (e.g. initState +
      // pull-to-refresh) must never race and orphan a live subscription —
      // the guard makes the second (and every subsequent) dispatch a pure
      // no-op instead.
      if (_watchStarted) return;
      _watchStarted = true;
      _animalsSubscription = watchAnimals().listen(
        (animals) => add(_AnimalsUpdated(animals)),
        onError: (Object error, StackTrace stackTrace) {
          appLogger.logError('AnimalBloc.watchAnimals', error, stackTrace);
          add(_AnimalsWatchFailed('Live sync interrupted. Pull to refresh.'));
        },
        onDone: () {
          appLogger.info(
            LogCategory.farm,
            'AnimalBloc.watchAnimals stream completed',
          );
        },
      );
    });

    on<_AnimalsUpdated>((event, emit) {
      emit(AnimalLoaded(animals: event.animals));
    });

    on<_AnimalsWatchFailed>((event, emit) {
      emit(AnimalError(event.message, animals: state.animals));
    });

    on<AddAnimalEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await addAnimal(AddAnimalParams(animal: event.animal));
        result.fold(
          (failure) => emit(
            AnimalError(
              resolveFailureMessage(failure, 'Failed to add animal'),
              animals: state.animals,
            ),
          ),
          (_) => emit(
            AnimalLoaded(animals: state.animals, successMessage: 'Animal added'),
          ),
        );
        return;
      }

      final currentAnimals = state.animals;

      emit(AnimalLoading(animals: currentAnimals));
      final result = await addAnimal(AddAnimalParams(animal: event.animal));
      result.fold(
        (failure) => emit(AnimalError(
          resolveFailureMessage(failure, 'Failed to add animal'),
          animals: currentAnimals,
        )),
        (animal) {
          final updatedAnimals = List<Animal>.from(currentAnimals)..add(animal);
          emit(AnimalLoaded(animals: updatedAnimals, successMessage: 'Animal added'));
        },
      );
    });

    on<UpdateAnimalEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await updateAnimal(UpdateAnimalParams(animal: event.animal));
        result.fold(
          (failure) => emit(
            AnimalError(
              resolveFailureMessage(failure, 'Failed to update animal'),
              animals: state.animals,
            ),
          ),
          (_) => emit(
            AnimalLoaded(animals: state.animals, successMessage: 'Animal updated'),
          ),
        );
        return;
      }

      final currentAnimals = state.animals;

      emit(AnimalLoading(animals: currentAnimals));
      final result = await updateAnimal(UpdateAnimalParams(animal: event.animal));
      result.fold(
        (failure) => emit(AnimalError(
          resolveFailureMessage(failure, 'Failed to update animal'),
          animals: currentAnimals,
        )),
        (updatedAnimal) {
          final updatedAnimals = currentAnimals.map((animal) {
            return animal.id == updatedAnimal.id ? updatedAnimal : animal;
          }).toList();
          emit(AnimalLoaded(animals: updatedAnimals, successMessage: 'Animal updated'));
        },
      );
    });

    on<DeleteAnimalEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await deleteAnimal(DeleteAnimalParams(id: event.id));
        result.fold(
          (failure) => emit(
            AnimalError(
              resolveFailureMessage(failure, 'Failed to delete animal'),
              animals: state.animals,
            ),
          ),
          (_) => emit(
            AnimalLoaded(animals: state.animals, successMessage: 'Animal deleted'),
          ),
        );
        return;
      }

      final currentAnimals = state.animals;

      emit(AnimalLoading(animals: currentAnimals));
      final result = await deleteAnimal(DeleteAnimalParams(id: event.id));
      result.fold(
        (failure) => emit(AnimalError(
          resolveFailureMessage(failure, 'Failed to delete animal'),
          animals: currentAnimals,
        )),
        (_) {
          final updatedAnimals =
              currentAnimals.where((animal) => animal.id != event.id).toList();
          emit(AnimalLoaded(animals: updatedAnimals, successMessage: 'Animal deleted'));
        },
      );
    });
  }
  final GetAnimals getAnimals;
  final AddAnimal addAnimal;
  final UpdateAnimal updateAnimal;
  final DeleteAnimal deleteAnimal;
  final WatchAnimals watchAnimals;

  StreamSubscription<List<Animal>>? _animalsSubscription;
  bool _watchStarted = false;

  @override
  Future<void> close() async {
    await _animalsSubscription?.cancel();
    return super.close();
  }
}
