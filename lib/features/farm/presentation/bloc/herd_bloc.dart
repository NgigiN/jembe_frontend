import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchHerdsEvent` handler below listens to `watchHerds()` and funnels
/// every emission back through the bloc's own event queue via `add(...)`
/// instead of calling `emit` directly from the stream callback — the
/// standard bloc pattern for turning an external stream into state, since
/// `emit` is only valid while its owning `on<...>` handler is still active.
class _HerdsUpdated extends HerdEvent {
  _HerdsUpdated(this.herds);
  final List<Herd> herds;

  @override
  List<Object> get props => [herds];
}

/// Internal-only event: the `WatchHerdsEvent` handler's stream subscription
/// routes its `onError` through here (same reasoning as `_HerdsUpdated` —
/// `emit` is only valid inside an active `on<...>` handler, not from a raw
/// stream callback). Non-fatal: it surfaces a `HerdError` over the last
/// known `herds` snapshot rather than crashing the bloc or dropping
/// reactivity — the subscription is NOT cancelled, so a later emission (if
/// the underlying stream keeps going) still comes through.
class _HerdsWatchFailed extends HerdEvent {
  _HerdsWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class HerdBloc extends Bloc<HerdEvent, HerdState> {
  HerdBloc({required this.repository}) : super(HerdInitial()) {
    on<GetHerdsEvent>(_onGetHerds);
    on<LoadMoreHerdsEvent>(_onLoadMoreHerds);
    on<WatchHerdsEvent>(_onWatchHerds);
    on<_HerdsUpdated>((event, emit) {
      emit(HerdLoaded(event.herds));
    });
    on<_HerdsWatchFailed>((event, emit) {
      emit(HerdError(event.message, herds: state.herds));
    });
    on<AddHerdEvent>(_onAddHerd);
    on<UpdateHerdEvent>(_onUpdateHerd);
    on<DeleteHerdEvent>(_onDeleteHerd);
  }
  final HerdRepository repository;

  StreamSubscription<List<Herd>>? _herdsSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMoreHerdsEvent]: guards against a second
  /// page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  Future<void> _onGetHerds(
    GetHerdsEvent event,
    Emitter<HerdState> emit,
  ) async {
    emit(const HerdLoading());
    final result = await repository.getHerds(limit: kOnlineListPageSize);
    result.fold(
      (failure) => emit(HerdError(resolveFailureMessage(failure, 'Failed to load herds'))),
      (herds) {
        // Online (flag off): this was page 1 of a cursor-paged list.
        // Offline returns the whole local mirror in one shot, so it always
        // reaches max here and never pages.
        final online = !OfflineConfig.enabled;
        emit(HerdLoaded(
          herds,
          hasReachedMax: !online || herds.length < kOnlineListPageSize,
          nextCursor: online ? _cursorOf(herds) : null,
        ));
      },
    );
  }

  /// Fetches and APPENDS the next online page. No-op when offline, when the
  /// current loaded page already reached max, when there is no cursor to page
  /// from, or when a load-more is already running.
  Future<void> _onLoadMoreHerds(
    LoadMoreHerdsEvent event,
    Emitter<HerdState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! HerdLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getHerds(
        limit: kOnlineListPageSize,
        cursor: current.nextCursor,
      );
      _isLoadingMore = false;
      result.fold(
        (failure) {
          if (state != current) return;
          emit(HerdError(
            resolveFailureMessage(failure, 'Failed to load herds'),
            herds: current.herds,
          ));
        },
        (more) {
          // A concurrent Add/Update/Delete/refresh emitted a newer state
          // while this fetch was in flight: drop this now-stale page rather
          // than clobbering it — the user's next scroll re-triggers
          // LoadMore against the fresh state.
          if (state != current) return;
          final combined = List<Herd>.from(current.herds)..addAll(more);
          emit(HerdLoaded(
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
  int? _cursorOf(List<Herd> herds) =>
      herds.isEmpty ? null : int.tryParse(herds.last.id);

  void _onWatchHerds(WatchHerdsEvent event, Emitter<HerdState> emit) {
    // Synchronous handler, no `await` before the guard: dispatching
    // WatchHerdsEvent twice in quick succession (e.g. initState +
    // pull-to-refresh) must never race and orphan a live subscription — the
    // guard makes the second (and every subsequent) dispatch a pure no-op
    // instead.
    if (_watchStarted) return;
    _watchStarted = true;
    _herdsSubscription = repository.watchHerds().listen(
      (herds) => add(_HerdsUpdated(herds)),
      onError: (Object error, StackTrace stackTrace) {
        appLogger.logError('HerdBloc.watchHerds', error, stackTrace);
        add(_HerdsWatchFailed('Live sync interrupted. Pull to refresh.'));
      },
      onDone: () {
        appLogger.info(
          LogCategory.farm,
          'HerdBloc.watchHerds stream completed',
        );
      },
    );
  }

  Future<void> _onAddHerd(
    AddHerdEvent event,
    Emitter<HerdState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.addHerd(
        event.name,
        event.animalTypeId,
        event.location,
        event.userId,
        event.initialHeadCount,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      result.fold(
        (failure) => emit(HerdError(
          resolveFailureMessage(failure, 'Failed to add herd'),
          herds: state.herds,
        )),
        (_) => emit(HerdLoaded(state.herds, successMessage: 'Herd created')),
      );
      return;
    }

    final currentHerds = state.herds;

    emit(HerdLoading(herds: currentHerds));
    final result = await repository.addHerd(
      event.name,
      event.animalTypeId,
      event.location,
      event.userId,
      event.initialHeadCount,
      startDate: event.startDate,
      endDate: event.endDate,
    );
    result.fold(
      (failure) => emit(HerdError(
        resolveFailureMessage(failure, 'Failed to add herd'),
        herds: currentHerds,
      )),
      (herd) {
        final updatedHerds = List<Herd>.from(currentHerds)..add(herd);
        emit(HerdLoaded(updatedHerds, successMessage: 'Herd created'));
      },
    );
  }

  Future<void> _onUpdateHerd(
    UpdateHerdEvent event,
    Emitter<HerdState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.updateHerd(
        event.id,
        event.name,
        event.animalTypeId,
        event.location,
        event.initialHeadCount,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      result.fold(
        (failure) => emit(HerdError(
          resolveFailureMessage(failure, 'Failed to update herd'),
          herds: state.herds,
        )),
        (_) => emit(HerdLoaded(state.herds, successMessage: 'Herd updated')),
      );
      return;
    }

    final currentHerds = state.herds;
    emit(HerdLoading(herds: currentHerds));
    final result = await repository.updateHerd(
      event.id,
      event.name,
      event.animalTypeId,
      event.location,
      event.initialHeadCount,
      startDate: event.startDate,
      endDate: event.endDate,
    );
    result.fold(
      (failure) => emit(HerdError(
        resolveFailureMessage(failure, 'Failed to update herd'),
        herds: currentHerds,
      )),
      (updatedHerd) {
        final updatedHerds = currentHerds.map((herd) {
          return herd.id == updatedHerd.id ? updatedHerd : herd;
        }).toList();
        emit(HerdLoaded(updatedHerds, successMessage: 'Herd updated'));
      },
    );
  }

  Future<void> _onDeleteHerd(
    DeleteHerdEvent event,
    Emitter<HerdState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.deleteHerd(event.id);
      result.fold(
        (failure) => emit(HerdError(
          resolveFailureMessage(failure, 'Failed to delete herd'),
          herds: state.herds,
        )),
        (_) => emit(HerdLoaded(state.herds, successMessage: 'Herd deleted')),
      );
      return;
    }

    final currentHerds = state.herds;
    emit(HerdLoading(herds: currentHerds));
    final result = await repository.deleteHerd(event.id);
    result.fold(
      (failure) => emit(HerdError(
        resolveFailureMessage(failure, 'Failed to delete herd'),
        herds: currentHerds,
      )),
      (_) {
        final updatedHerds =
            currentHerds.where((herd) => herd.id != event.id).toList();
        emit(HerdLoaded(updatedHerds, successMessage: 'Herd deleted'));
      },
    );
  }

  @override
  Future<void> close() async {
    await _herdsSubscription?.cancel();
    return super.close();
  }
}
