import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchHarvestsEvent` handler below listens to `watchHarvests(seasonId:)`
/// and funnels every emission back through the bloc's own event queue via
/// `add(...)` instead of calling `emit` directly from the stream callback —
/// the standard bloc pattern for turning an external stream into state,
/// since `emit` is only valid while its owning `on<...>` handler is still
/// active.
class _HarvestsUpdated extends HarvestEvent {
  _HarvestsUpdated(this.harvests);
  final List<Harvest> harvests;

  @override
  List<Object> get props => [harvests];
}

/// Internal-only event: the `WatchHarvestsEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_HarvestsUpdated` — `emit` is only valid inside an active `on<...>`
/// handler, not from a raw stream callback). Non-fatal: it surfaces a
/// `HarvestError` over the last known `harvests` snapshot rather than
/// crashing the bloc or dropping reactivity — the subscription is NOT
/// cancelled, so a later emission (if the underlying stream keeps going)
/// still comes through.
class _HarvestsWatchFailed extends HarvestEvent {
  _HarvestsWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class HarvestBloc extends Bloc<HarvestEvent, HarvestState> {
  HarvestBloc({required this.repository}) : super(HarvestInitial()) {
    on<GetHarvestsEvent>(_onGetHarvests);
    on<LoadMoreHarvestsEvent>(_onLoadMoreHarvests);
    on<WatchHarvestsEvent>(_onWatchHarvests);
    on<_HarvestsUpdated>((event, emit) {
      emit(HarvestLoaded(harvests: event.harvests));
    });
    on<_HarvestsWatchFailed>((event, emit) {
      emit(HarvestError(event.message, harvests: state.harvests));
    });
    on<AddHarvestEvent>(_onAddHarvest);
    on<UpdateHarvestEvent>(_onUpdateHarvest);
    on<DeleteHarvestEvent>(_onDeleteHarvest);
  }

  final HarvestRepository repository;

  StreamSubscription<List<Harvest>>? _harvestsSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMoreHarvestsEvent]: guards against a second
  /// page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  Future<void> _onGetHarvests(
    GetHarvestsEvent event,
    Emitter<HarvestState> emit,
  ) async {
    emit(HarvestLoading(harvests: state.harvests));
    final result = await repository.getHarvests(
      seasonId: event.seasonId,
      limit: kOnlineListPageSize,
    );
    result.fold(
      (failure) => emit(HarvestError(
        resolveFailureMessage(failure, 'Failed to load harvests'),
        harvests: state.harvests,
      )),
      (harvests) {
        // Online (flag off): this was page 1 of a cursor-paged list. Offline
        // returns the whole local mirror in one shot, so it always reaches
        // max here and never pages.
        final online = !OfflineConfig.enabled;
        emit(HarvestLoaded(
          harvests: harvests,
          hasReachedMax:
              !online || harvests.length < kOnlineListPageSize,
          nextCursor: online ? _cursorOf(harvests) : null,
        ));
      },
    );
  }

  /// Fetches and APPENDS the next online page. No-op when offline, when the
  /// current loaded page already reached max, when there is no cursor to page
  /// from, or when a load-more is already running.
  Future<void> _onLoadMoreHarvests(
    LoadMoreHarvestsEvent event,
    Emitter<HarvestState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! HarvestLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getHarvests(
        seasonId: event.seasonId,
        limit: kOnlineListPageSize,
        cursor: current.nextCursor,
      );
      _isLoadingMore = false;
      result.fold(
        (failure) {
          if (state != current) return;
          emit(HarvestError(
            resolveFailureMessage(failure, 'Failed to load harvests'),
            harvests: current.harvests,
          ));
        },
        (more) {
          // A concurrent Add/Update/Delete/refresh emitted a newer state
          // while this fetch was in flight: drop this now-stale page rather
          // than clobbering it — the user's next scroll re-triggers
          // LoadMore against the fresh state.
          if (state != current) return;
          final combined = List<Harvest>.from(current.harvests)..addAll(more);
          emit(HarvestLoaded(
            harvests: combined,
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
  int? _cursorOf(List<Harvest> harvests) =>
      harvests.isEmpty ? null : int.tryParse(harvests.last.id);

  // Synchronous handler, no `await` before the guard: dispatching
  // WatchHarvestsEvent twice in quick succession (e.g. initState +
  // pull-to-refresh) must never race and orphan a live subscription — the
  // guard makes the second (and every subsequent) dispatch a pure no-op
  // instead.
  void _onWatchHarvests(
    WatchHarvestsEvent event,
    Emitter<HarvestState> emit,
  ) {
    if (_watchStarted) return;
    _watchStarted = true;
    _harvestsSubscription = repository.watchHarvests(seasonId: event.seasonId).listen(
      (harvests) => add(_HarvestsUpdated(harvests)),
      onError: (Object error, StackTrace stackTrace) {
        appLogger.logError('HarvestBloc.watchHarvests', error, stackTrace);
        add(_HarvestsWatchFailed('Live sync interrupted. Pull to refresh.'));
      },
      onDone: () {
        appLogger.info(
          LogCategory.farm,
          'HarvestBloc.watchHarvests stream completed',
        );
      },
    );
  }

  Future<void> _onAddHarvest(
    AddHarvestEvent event,
    Emitter<HarvestState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.addHarvest(event.harvest);
      result.fold(
        (failure) => emit(HarvestError(
          resolveFailureMessage(failure, 'Failed to add harvest'),
          harvests: state.harvests,
        )),
        (_) => emit(
          HarvestLoaded(harvests: state.harvests, successMessage: 'Harvest recorded'),
        ),
      );
      return;
    }

    final currentHarvests = state.harvests;
    emit(HarvestLoading(harvests: currentHarvests));
    final result = await repository.addHarvest(event.harvest);
    result.fold(
      (failure) => emit(HarvestError(
        resolveFailureMessage(failure, 'Failed to add harvest'),
        harvests: currentHarvests,
      )),
      (harvest) {
        final updated = List<Harvest>.from(currentHarvests)..add(harvest);
        emit(HarvestLoaded(harvests: updated, successMessage: 'Harvest recorded'));
      },
    );
  }

  Future<void> _onUpdateHarvest(
    UpdateHarvestEvent event,
    Emitter<HarvestState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.updateHarvest(event.harvest);
      result.fold(
        (failure) => emit(HarvestError(
          resolveFailureMessage(failure, 'Failed to update harvest'),
          harvests: state.harvests,
        )),
        (_) => emit(
          HarvestLoaded(harvests: state.harvests, successMessage: 'Harvest updated'),
        ),
      );
      return;
    }

    final currentHarvests = state.harvests;
    emit(HarvestLoading(harvests: currentHarvests));
    final result = await repository.updateHarvest(event.harvest);
    result.fold(
      (failure) => emit(HarvestError(
        resolveFailureMessage(failure, 'Failed to update harvest'),
        harvests: currentHarvests,
      )),
      (updatedHarvest) {
        final updated = currentHarvests
            .map((harvest) =>
                harvest.id == updatedHarvest.id ? updatedHarvest : harvest)
            .toList();
        emit(HarvestLoaded(harvests: updated, successMessage: 'Harvest updated'));
      },
    );
  }

  Future<void> _onDeleteHarvest(
    DeleteHarvestEvent event,
    Emitter<HarvestState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.deleteHarvest(event.id);
      result.fold(
        (failure) => emit(HarvestError(
          resolveFailureMessage(failure, 'Failed to delete harvest'),
          harvests: state.harvests,
        )),
        (_) => emit(
          HarvestLoaded(harvests: state.harvests, successMessage: 'Harvest deleted'),
        ),
      );
      return;
    }

    final currentHarvests = state.harvests;
    emit(HarvestLoading(harvests: currentHarvests));
    final result = await repository.deleteHarvest(event.id);
    result.fold(
      (failure) => emit(HarvestError(
        resolveFailureMessage(failure, 'Failed to delete harvest'),
        harvests: currentHarvests,
      )),
      (_) {
        final updated = currentHarvests
            .where((harvest) => harvest.id != event.id)
            .toList();
        emit(HarvestLoaded(harvests: updated, successMessage: 'Harvest deleted'));
      },
    );
  }

  @override
  Future<void> close() async {
    await _harvestsSubscription?.cancel();
    return super.close();
  }
}
