import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';
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
  AnimalBloc({required this.repository}) : super(AnimalInitial()) {
    on<GetAnimalsEvent>((event, emit) async {
      emit(const AnimalLoading());
      final result = await repository.getAnimals(limit: kOnlineListPageSize);
      result.fold(
        (failure) => emit(
          AnimalError(resolveFailureMessage(failure, 'Failed to load animals')),
        ),
        (animals) {
          // Online (flag off): this was page 1 of a cursor-paged list.
          // Offline returns the whole local mirror in one shot, so it
          // always reaches max here and never pages.
          final online = !OfflineConfig.enabled;
          emit(AnimalLoaded(
            animals: animals,
            hasReachedMax: !online || animals.length < kOnlineListPageSize,
            nextCursor: online ? _cursorOf(animals) : null,
          ));
        },
      );
    });

    on<LoadMoreAnimalsEvent>(_onLoadMoreAnimals);

    on<WatchAnimalsEvent>((event, emit) {
      // Synchronous handler, no `await` before the guard: dispatching
      // WatchAnimalsEvent twice in quick succession (e.g. initState +
      // pull-to-refresh) must never race and orphan a live subscription —
      // the guard makes the second (and every subsequent) dispatch a pure
      // no-op instead.
      if (_watchStarted) return;
      _watchStarted = true;
      _animalsSubscription = repository.watchAnimals().listen(
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
        final result = await repository.addAnimal(event.animal);
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
      final result = await repository.addAnimal(event.animal);
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
        final result = await repository.updateAnimal(event.animal);
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
      final result = await repository.updateAnimal(event.animal);
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
        final result = await repository.deleteAnimal(event.id);
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
      final result = await repository.deleteAnimal(event.id);
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
  final AnimalRepository repository;

  StreamSubscription<List<Animal>>? _animalsSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMoreAnimalsEvent]: guards against a second
  /// page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  /// Fetches and APPENDS the next online page. No-op when offline, when the
  /// current loaded page already reached max, when there is no cursor to page
  /// from, or when a load-more is already running.
  Future<void> _onLoadMoreAnimals(
    LoadMoreAnimalsEvent event,
    Emitter<AnimalState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! AnimalLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getAnimals(
        limit: kOnlineListPageSize,
        cursor: current.nextCursor,
      );
      _isLoadingMore = false;
      result.fold(
        (failure) {
          if (state != current) return;
          emit(AnimalError(
            resolveFailureMessage(failure, 'Failed to load animals'),
            animals: current.animals,
          ));
        },
        (more) {
          // A concurrent Add/Update/Delete/refresh emitted a newer state
          // while this fetch was in flight: drop this now-stale page rather
          // than clobbering it — the user's next scroll re-triggers
          // LoadMore against the fresh state.
          if (state != current) return;
          final combined = List<Animal>.from(current.animals)..addAll(more);
          emit(AnimalLoaded(
            animals: combined,
            hasReachedMax: more.length < kOnlineListPageSize,
            nextCursor: _cursorOf(more),
          ));
        },
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  /// The next `?cursor=` value — the last (oldest, since the list is
  /// newest-first) item's server id, or `null` when the page is empty.
  int? _cursorOf(List<Animal> animals) =>
      animals.isEmpty ? null : int.tryParse(animals.last.id);

  @override
  Future<void> close() async {
    await _animalsSubscription?.cancel();
    return super.close();
  }
}
