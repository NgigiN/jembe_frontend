import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchLandsEvent` handler below listens to `watchLands()` and funnels
/// every emission back through the bloc's own event queue via `add(...)`
/// instead of calling `emit` directly from the stream callback — the
/// standard bloc pattern for turning an external stream into state, since
/// `emit` is only valid while its owning `on<...>` handler is still active.
class _LandsUpdated extends LandEvent {
  _LandsUpdated(this.lands);
  final List<Land> lands;

  @override
  List<Object> get props => [lands];
}

/// Internal-only event: the `WatchLandsEvent` handler's stream subscription
/// routes its `onError` through here (same reasoning as `_LandsUpdated` —
/// `emit` is only valid inside an active `on<...>` handler, not from a raw
/// stream callback). Non-fatal: it surfaces a `LandError` over the last
/// known `lands` snapshot rather than crashing the bloc or dropping
/// reactivity — the subscription is NOT cancelled, so a later emission (if
/// the underlying stream keeps going) still comes through.
class _LandsWatchFailed extends LandEvent {
  _LandsWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class LandBloc extends Bloc<LandEvent, LandState> {
  LandBloc({required this.repository}) : super(LandInitial()) {
    on<GetLandsEvent>((event, emit) async {
      emit(const LandLoading());
      final result = await repository.getLands(limit: kOnlineListPageSize);
      result.fold(
        (failure) => emit(
          LandError(resolveFailureMessage(failure, 'Failed to load lands')),
        ),
        (lands) {
          // Online (flag off): this was page 1 of a cursor-paged list.
          // Offline returns the whole local mirror in one shot, so it
          // always reaches max here and never pages.
          final online = !OfflineConfig.enabled;
          emit(LandLoaded(
            lands: lands,
            hasReachedMax: !online || lands.length < kOnlineListPageSize,
            nextCursor: online ? _cursorOf(lands) : null,
          ));
        },
      );
    });

    on<LoadMoreLandsEvent>(_onLoadMoreLands);

    on<WatchLandsEvent>((event, emit) {
      // Synchronous handler, no `await` before the guard: dispatching
      // WatchLandsEvent twice in quick succession (e.g. initState +
      // pull-to-refresh) must never race and orphan a live subscription —
      // the guard makes the second (and every subsequent) dispatch a
      // pure no-op instead.
      if (_watchStarted) return;
      _watchStarted = true;
      _landsSubscription = repository.watchLands().listen(
        (lands) => add(_LandsUpdated(lands)),
        onError: (Object error, StackTrace stackTrace) {
          appLogger.logError('LandBloc.watchLands', error, stackTrace);
          add(_LandsWatchFailed('Live sync interrupted. Pull to refresh.'));
        },
        onDone: () {
          appLogger.info(
            LogCategory.farm,
            'LandBloc.watchLands stream completed',
          );
        },
      );
    });

    on<_LandsUpdated>((event, emit) {
      emit(LandLoaded(lands: event.lands));
    });

    on<_LandsWatchFailed>((event, emit) {
      emit(LandError(event.message, lands: state.lands));
    });

    on<AddLandEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await repository.addLand(event.land);
        result.fold(
          (failure) => emit(
            LandError(
              resolveFailureMessage(failure, 'Failed to add land'),
              lands: state.lands,
            ),
          ),
          (addedLand) => emit(
            LandLoaded(
              lands: state.lands,
              successMessage: 'Land added',
              addedLandId: addedLand.id,
            ),
          ),
        );
        return;
      }

      final currentLands = state.lands;

      emit(LandLoading(lands: currentLands));
      final result = await repository.addLand(event.land);
      result.fold(
        (failure) => emit(
          LandError(
            resolveFailureMessage(failure, 'Failed to add land'),
            lands: currentLands,
          ),
        ),
        (land) {
          final updatedLands = List<Land>.from(currentLands)..add(land);
          emit(
            LandLoaded(
              lands: updatedLands,
              successMessage: 'Land added',
              addedLandId: land.id,
            ),
          );
        },
      );
    });

    on<UpdateLandEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await repository.updateLand(event.land);
        result.fold(
          (failure) => emit(
            LandError(
              resolveFailureMessage(failure, 'Failed to update land'),
              lands: state.lands,
            ),
          ),
          (_) => emit(
            LandLoaded(lands: state.lands, successMessage: 'Land updated'),
          ),
        );
        return;
      }

      final currentLands = state.lands;

      emit(LandLoading(lands: currentLands));
      final result = await repository.updateLand(event.land);
      result.fold(
        (failure) => emit(
          LandError(
            resolveFailureMessage(failure, 'Failed to update land'),
            lands: currentLands,
          ),
        ),
        (updatedLand) {
          final updatedLands = currentLands.map((land) {
            return land.id == updatedLand.id ? updatedLand : land;
          }).toList();
          emit(LandLoaded(lands: updatedLands, successMessage: 'Land updated'));
        },
      );
    });

    on<DeleteLandEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await repository.deleteLand(event.id);
        result.fold(
          (failure) => emit(
            LandError(
              resolveFailureMessage(failure, 'Failed to delete land'),
              lands: state.lands,
            ),
          ),
          (_) => emit(
            LandLoaded(lands: state.lands, successMessage: 'Land deleted'),
          ),
        );
        return;
      }

      final currentLands = state.lands;

      emit(LandLoading(lands: currentLands));
      final result = await repository.deleteLand(event.id);
      result.fold(
        (failure) => emit(
          LandError(
            resolveFailureMessage(failure, 'Failed to delete land'),
            lands: currentLands,
          ),
        ),
        (_) {
          final updatedLands = currentLands
              .where((land) => land.id != event.id)
              .toList();
          emit(LandLoaded(lands: updatedLands, successMessage: 'Land deleted'));
        },
      );
    });
  }
  final LandRepository repository;

  StreamSubscription<List<Land>>? _landsSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMoreLandsEvent]: guards against a second
  /// page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  /// Fetches and APPENDS the next online page. No-op when offline, when the
  /// current loaded page already reached max, when there is no cursor to page
  /// from, or when a load-more is already running.
  Future<void> _onLoadMoreLands(
    LoadMoreLandsEvent event,
    Emitter<LandState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! LandLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getLands(
        limit: kOnlineListPageSize,
        cursor: current.nextCursor,
      );
      _isLoadingMore = false;
      result.fold(
        (failure) {
          if (state != current) return;
          emit(LandError(
            resolveFailureMessage(failure, 'Failed to load lands'),
            lands: current.lands,
          ));
        },
        (more) {
          // A concurrent Add/Update/Delete/refresh emitted a newer state
          // while this fetch was in flight: drop this now-stale page rather
          // than clobbering it — the user's next scroll re-triggers
          // LoadMore against the fresh state.
          if (state != current) return;
          final combined = List<Land>.from(current.lands)..addAll(more);
          emit(LandLoaded(
            lands: combined,
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
  int? _cursorOf(List<Land> lands) =>
      lands.isEmpty ? null : int.tryParse(lands.last.id);

  @override
  Future<void> close() async {
    await _landsSubscription?.cancel();
    return super.close();
  }
}
