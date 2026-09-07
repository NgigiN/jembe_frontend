import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchPlantsEvent` handler below listens to `watchPlants()` and funnels
/// every emission back through the bloc's own event queue via `add(...)`
/// instead of calling `emit` directly from the stream callback — the
/// standard bloc pattern for turning an external stream into state, since
/// `emit` is only valid while its owning `on<...>` handler is still active.
class _PlantsUpdated extends PlantEvent {
  _PlantsUpdated(this.plants);
  final List<Plant> plants;

  @override
  List<Object> get props => [plants];
}

/// Internal-only event: the `WatchPlantsEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_PlantsUpdated` — `emit` is only valid inside an active `on<...>`
/// handler, not from a raw stream callback). Non-fatal: it surfaces a
/// `PlantError` over the last known `plants` snapshot rather than crashing
/// the bloc or dropping reactivity — the subscription is NOT cancelled, so
/// a later emission (if the underlying stream keeps going) still comes
/// through.
class _PlantsWatchFailed extends PlantEvent {
  _PlantsWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class PlantBloc extends Bloc<PlantEvent, PlantState> {
  PlantBloc({required this.repository}) : super(PlantInitial()) {
    on<GetPlantsEvent>((event, emit) async {
      emit(const PlantLoading());
      final result = await repository.getPlants(limit: kOnlineListPageSize);
      result.fold(
        (failure) => emit(
          PlantError(resolveFailureMessage(failure, 'Failed to load crops')),
        ),
        (plants) {
          // Online (flag off): this was page 1 of a cursor-paged list.
          // Offline returns the whole local mirror in one shot, so it
          // always reaches max here and never pages.
          final online = !OfflineConfig.enabled;
          emit(PlantLoaded(
            plants: plants,
            hasReachedMax: !online || plants.length < kOnlineListPageSize,
            nextCursor: online ? _cursorOf(plants) : null,
          ));
        },
      );
    });

    on<LoadMorePlantsEvent>(_onLoadMorePlants);

    on<WatchPlantsEvent>((event, emit) {
      // Synchronous handler, no `await` before the guard: dispatching
      // WatchPlantsEvent twice in quick succession (e.g. initState +
      // pull-to-refresh) must never race and orphan a live subscription —
      // the guard makes the second (and every subsequent) dispatch a pure
      // no-op instead.
      if (_watchStarted) return;
      _watchStarted = true;
      _plantsSubscription = repository.watchPlants().listen(
        (plants) => add(_PlantsUpdated(plants)),
        onError: (Object error, StackTrace stackTrace) {
          appLogger.logError('PlantBloc.watchPlants', error, stackTrace);
          add(_PlantsWatchFailed('Live sync interrupted. Pull to refresh.'));
        },
        onDone: () {
          appLogger.info(
            LogCategory.farm,
            'PlantBloc.watchPlants stream completed',
          );
        },
      );
    });

    on<_PlantsUpdated>((event, emit) {
      emit(PlantLoaded(plants: event.plants));
    });

    on<_PlantsWatchFailed>((event, emit) {
      emit(PlantError(event.message, plants: state.plants));
    });

    on<AddPlantEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await repository.addPlant(event.plant);
        result.fold(
          (failure) => emit(
            PlantError(
              resolveFailureMessage(failure, 'Failed to add crop'),
              plants: state.plants,
            ),
          ),
          (_) => emit(
            PlantLoaded(plants: state.plants, successMessage: 'Crop added'),
          ),
        );
        return;
      }

      final currentPlants = state.plants;

      emit(PlantLoading(plants: currentPlants));
      final result = await repository.addPlant(event.plant);
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
      if (OfflineConfig.enabled) {
        final result = await repository.updatePlant(event.plant);
        result.fold(
          (failure) => emit(
            PlantError(
              resolveFailureMessage(failure, 'Failed to update crop'),
              plants: state.plants,
            ),
          ),
          (_) => emit(
            PlantLoaded(plants: state.plants, successMessage: 'Crop updated'),
          ),
        );
        return;
      }

      final currentPlants = state.plants;

      emit(PlantLoading(plants: currentPlants));
      final result = await repository.updatePlant(event.plant);
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
      if (OfflineConfig.enabled) {
        final result = await repository.deletePlant(event.id);
        result.fold(
          (failure) => emit(
            PlantError(
              resolveFailureMessage(failure, 'Failed to delete crop'),
              plants: state.plants,
            ),
          ),
          (_) => emit(
            PlantLoaded(plants: state.plants, successMessage: 'Crop deleted'),
          ),
        );
        return;
      }

      final currentPlants = state.plants;

      emit(PlantLoading(plants: currentPlants));
      final result = await repository.deletePlant(event.id);
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
  final PlantRepository repository;

  StreamSubscription<List<Plant>>? _plantsSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMorePlantsEvent]: guards against a second
  /// page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  /// Fetches and APPENDS the next online page. No-op when offline, when the
  /// current loaded page already reached max, when there is no cursor to page
  /// from, or when a load-more is already running.
  Future<void> _onLoadMorePlants(
    LoadMorePlantsEvent event,
    Emitter<PlantState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! PlantLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getPlants(
        limit: kOnlineListPageSize,
        cursor: current.nextCursor,
      );
      _isLoadingMore = false;
      result.fold(
        (failure) {
          if (state != current) return;
          emit(PlantError(
            resolveFailureMessage(failure, 'Failed to load crops'),
            plants: current.plants,
          ));
        },
        (more) {
          // A concurrent Add/Update/Delete/refresh emitted a newer state
          // while this fetch was in flight: drop this now-stale page rather
          // than clobbering it — the user's next scroll re-triggers
          // LoadMore against the fresh state.
          if (state != current) return;
          final combined = List<Plant>.from(current.plants)..addAll(more);
          emit(PlantLoaded(
            plants: combined,
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
  int? _cursorOf(List<Plant> plants) =>
      plants.isEmpty ? null : int.tryParse(plants.last.id);

  @override
  Future<void> close() async {
    await _plantsSubscription?.cancel();
    return super.close();
  }
}
