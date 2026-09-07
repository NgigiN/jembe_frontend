import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_type_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchAnimalTypesEvent` handler below listens to `watchAnimalTypes()` and
/// funnels every emission back through the bloc's own event queue via
/// `add(...)` instead of calling `emit` directly from the stream callback —
/// the standard bloc pattern for turning an external stream into state,
/// since `emit` is only valid while its owning `on<...>` handler is still
/// active.
class _AnimalTypesUpdated extends AnimalTypeEvent {
  _AnimalTypesUpdated(this.animalTypes);
  final List<AnimalType> animalTypes;

  @override
  List<Object> get props => [animalTypes];
}

/// Internal-only event: the `WatchAnimalTypesEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_AnimalTypesUpdated` — `emit` is only valid inside an active `on<...>`
/// handler, not from a raw stream callback). Non-fatal: it surfaces an
/// `AnimalTypeError` over the last known `animalTypes` snapshot rather than
/// crashing the bloc or dropping reactivity — the subscription is NOT
/// cancelled, so a later emission (if the underlying stream keeps going)
/// still comes through.
class _AnimalTypesWatchFailed extends AnimalTypeEvent {
  _AnimalTypesWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class AnimalTypeBloc extends Bloc<AnimalTypeEvent, AnimalTypeState> {
  AnimalTypeBloc({required this.repository}) : super(AnimalTypeInitial()) {
    on<GetAnimalTypesEvent>(_onGetAnimalTypes);
    on<LoadMoreAnimalTypesEvent>(_onLoadMoreAnimalTypes);
    on<WatchAnimalTypesEvent>(_onWatchAnimalTypes);
    on<_AnimalTypesUpdated>((event, emit) {
      emit(AnimalTypeLoaded(event.animalTypes));
    });
    on<_AnimalTypesWatchFailed>((event, emit) {
      emit(AnimalTypeError(event.message, animalTypes: state.animalTypes));
    });
    on<AddAnimalTypeEvent>(_onAddAnimalType);
    on<UpdateAnimalTypeEvent>(_onUpdateAnimalType);
    on<DeleteAnimalTypeEvent>(_onDeleteAnimalType);
  }
  final AnimalTypeRepository repository;

  StreamSubscription<List<AnimalType>>? _animalTypesSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMoreAnimalTypesEvent]: guards against a
  /// second page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  Future<void> _onGetAnimalTypes(
    GetAnimalTypesEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    emit(const AnimalTypeLoading());
    final result = await repository.getAnimalTypes(
      limit: kOnlineListPageSize,
    );
    result.fold(
      (failure) => emit(AnimalTypeError(
        resolveFailureMessage(failure, 'Failed to load animal types'),
      )),
      (animalTypes) {
        // Online (flag off): this was page 1 of a cursor-paged list.
        // Offline returns the whole local mirror in one shot, so it always
        // reaches max here and never pages.
        final online = !OfflineConfig.enabled;
        emit(AnimalTypeLoaded(
          animalTypes,
          hasReachedMax: !online || animalTypes.length < kOnlineListPageSize,
          nextCursor: online ? _cursorOf(animalTypes) : null,
        ));
      },
    );
  }

  /// Fetches and APPENDS the next online page. No-op when offline, when the
  /// current loaded page already reached max, when there is no cursor to page
  /// from, or when a load-more is already running.
  Future<void> _onLoadMoreAnimalTypes(
    LoadMoreAnimalTypesEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! AnimalTypeLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getAnimalTypes(
        limit: kOnlineListPageSize,
        cursor: current.nextCursor,
      );
      _isLoadingMore = false;
      result.fold(
        (failure) {
          if (state != current) return;
          emit(AnimalTypeError(
            resolveFailureMessage(failure, 'Failed to load animal types'),
            animalTypes: current.animalTypes,
          ));
        },
        (more) {
          // A concurrent Add/Update/Delete/refresh emitted a newer state
          // while this fetch was in flight: drop this now-stale page rather
          // than clobbering it — the user's next scroll re-triggers
          // LoadMore against the fresh state.
          if (state != current) return;
          final combined = List<AnimalType>.from(current.animalTypes)
            ..addAll(more);
          emit(AnimalTypeLoaded(
            combined,
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
  int? _cursorOf(List<AnimalType> animalTypes) =>
      animalTypes.isEmpty ? null : int.tryParse(animalTypes.last.id);

  void _onWatchAnimalTypes(
    WatchAnimalTypesEvent event,
    Emitter<AnimalTypeState> emit,
  ) {
    // Synchronous handler, no `await` before the guard: dispatching
    // WatchAnimalTypesEvent twice in quick succession (e.g. initState +
    // pull-to-refresh) must never race and orphan a live subscription — the
    // guard makes the second (and every subsequent) dispatch a pure no-op
    // instead.
    if (_watchStarted) return;
    _watchStarted = true;
    _animalTypesSubscription = repository.watchAnimalTypes().listen(
      (animalTypes) => add(_AnimalTypesUpdated(animalTypes)),
      onError: (Object error, StackTrace stackTrace) {
        appLogger.logError('AnimalTypeBloc.watchAnimalTypes', error, stackTrace);
        add(_AnimalTypesWatchFailed('Live sync interrupted. Pull to refresh.'));
      },
      onDone: () {
        appLogger.info(
          LogCategory.farm,
          'AnimalTypeBloc.watchAnimalTypes stream completed',
        );
      },
    );
  }

  Future<void> _onAddAnimalType(
    AddAnimalTypeEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.addAnimalType(event.name, event.notes, event.userId);
      result.fold(
        (failure) => emit(AnimalTypeError(
          resolveFailureMessage(failure, 'Failed to add animal type'),
          animalTypes: state.animalTypes,
        )),
        (_) => emit(
          AnimalTypeLoaded(state.animalTypes, successMessage: 'Animal type added'),
        ),
      );
      return;
    }

    final currentAnimalTypes = state.animalTypes;

    emit(AnimalTypeLoading(animalTypes: currentAnimalTypes));
    final result = await repository.addAnimalType(event.name, event.notes, event.userId);
    result.fold(
      (failure) => emit(AnimalTypeError(
        resolveFailureMessage(failure, 'Failed to add animal type'),
        animalTypes: currentAnimalTypes,
      )),
      (animalType) {
        final updatedAnimalTypes = List<AnimalType>.from(currentAnimalTypes)
          ..add(animalType);
        emit(AnimalTypeLoaded(updatedAnimalTypes, successMessage: 'Animal type added'));
      },
    );
  }

  Future<void> _onUpdateAnimalType(
    UpdateAnimalTypeEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.updateAnimalType(event.id, event.name, event.notes);
      result.fold(
        (failure) => emit(AnimalTypeError(
          resolveFailureMessage(failure, 'Failed to update animal type'),
          animalTypes: state.animalTypes,
        )),
        (_) => emit(
          AnimalTypeLoaded(state.animalTypes, successMessage: 'Animal type updated'),
        ),
      );
      return;
    }

    final currentAnimalTypes = state.animalTypes;
    emit(AnimalTypeLoading(animalTypes: currentAnimalTypes));
    final result = await repository.updateAnimalType(event.id, event.name, event.notes);
    result.fold(
      (failure) => emit(AnimalTypeError(
        resolveFailureMessage(failure, 'Failed to update animal type'),
        animalTypes: currentAnimalTypes,
      )),
      (updatedAnimalType) {
        final updatedAnimalTypes = currentAnimalTypes.map((type) {
          return type.id == updatedAnimalType.id ? updatedAnimalType : type;
        }).toList();
        emit(AnimalTypeLoaded(updatedAnimalTypes, successMessage: 'Animal type updated'));
      },
    );
  }

  Future<void> _onDeleteAnimalType(
    DeleteAnimalTypeEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.deleteAnimalType(event.id);
      result.fold(
        (failure) => emit(AnimalTypeError(
          resolveFailureMessage(failure, 'Failed to delete animal type'),
          animalTypes: state.animalTypes,
        )),
        (_) => emit(
          AnimalTypeLoaded(state.animalTypes, successMessage: 'Animal type deleted'),
        ),
      );
      return;
    }

    final currentAnimalTypes = state.animalTypes;
    emit(AnimalTypeLoading(animalTypes: currentAnimalTypes));
    final result = await repository.deleteAnimalType(event.id);
    result.fold(
      (failure) => emit(AnimalTypeError(
        resolveFailureMessage(failure, 'Failed to delete animal type'),
        animalTypes: currentAnimalTypes,
      )),
      (_) {
        final updatedAnimalTypes =
            currentAnimalTypes.where((type) => type.id != event.id).toList();
        emit(AnimalTypeLoaded(updatedAnimalTypes, successMessage: 'Animal type deleted'));
      },
    );
  }

  @override
  Future<void> close() async {
    await _animalTypesSubscription?.cancel();
    return super.close();
  }
}
