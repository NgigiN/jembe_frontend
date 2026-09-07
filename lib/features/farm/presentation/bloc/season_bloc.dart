import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchSeasonsEvent` handler below listens to `watchSeasons()` and
/// funnels every emission back through the bloc's own event queue via
/// `add(...)` instead of calling `emit` directly from the stream callback —
/// the standard bloc pattern for turning an external stream into state,
/// since `emit` is only valid while its owning `on<...>` handler is still
/// active.
class _SeasonsUpdated extends SeasonEvent {
  _SeasonsUpdated(this.seasons);
  final List<Season> seasons;

  @override
  List<Object> get props => [seasons];
}

/// Internal-only event: the `WatchSeasonsEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_SeasonsUpdated` — `emit` is only valid inside an active `on<...>`
/// handler, not from a raw stream callback). Non-fatal: it surfaces a
/// `SeasonError` over the last known `seasons` snapshot rather than
/// crashing the bloc or dropping reactivity — the subscription is NOT
/// cancelled, so a later emission (if the underlying stream keeps going)
/// still comes through.
class _SeasonsWatchFailed extends SeasonEvent {
  _SeasonsWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class SeasonBloc extends Bloc<SeasonEvent, SeasonState> {
  SeasonBloc({required this.repository}) : super(SeasonInitial()) {
    on<GetSeasonsEvent>((event, emit) async {
      appLogger.debug(LogCategory.farm, 'GetSeasonsEvent triggered');
      emit(const SeasonLoading());

      final result = await repository.getSeasons(limit: kOnlineListPageSize);
      result.fold(
        (failure) {
          appLogger.warning(LogCategory.farm, 'GetSeasons failed: $failure');
          emit(SeasonError(resolveFailureMessage(failure, 'Failed to load seasons')));
        },
        (seasons) {
          appLogger.info(LogCategory.farm, 'Loaded ${seasons.length} seasons');
          // Online (flag off): this was page 1 of a cursor-paged list.
          // Offline returns the whole local mirror in one shot, so it
          // always reaches max here and never pages.
          final online = !OfflineConfig.enabled;
          emit(SeasonLoaded(
            seasons: seasons,
            hasReachedMax: !online || seasons.length < kOnlineListPageSize,
            nextCursor: online ? _cursorOf(seasons) : null,
          ));
        },
      );
    });

    on<LoadMoreSeasonsEvent>(_onLoadMoreSeasons);

    on<WatchSeasonsEvent>((event, emit) {
      // Synchronous handler, no `await` before the guard: dispatching
      // WatchSeasonsEvent twice in quick succession (e.g. initState +
      // pull-to-refresh) must never race and orphan a live subscription —
      // the guard makes the second (and every subsequent) dispatch a pure
      // no-op instead.
      if (_watchStarted) return;
      _watchStarted = true;
      _seasonsSubscription = repository.watchSeasons().listen(
        (seasons) => add(_SeasonsUpdated(seasons)),
        onError: (Object error, StackTrace stackTrace) {
          appLogger.logError('SeasonBloc.watchSeasons', error, stackTrace);
          add(_SeasonsWatchFailed('Live sync interrupted. Pull to refresh.'));
        },
        onDone: () {
          appLogger.info(
            LogCategory.farm,
            'SeasonBloc.watchSeasons stream completed',
          );
        },
      );
    });

    on<_SeasonsUpdated>((event, emit) {
      emit(SeasonLoaded(seasons: event.seasons));
    });

    on<_SeasonsWatchFailed>((event, emit) {
      emit(SeasonError(event.message, seasons: state.seasons));
    });

    on<AddSeasonEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await repository.addSeason(event.season);
        result.fold(
          (failure) => emit(
            SeasonError(
              resolveFailureMessage(failure, 'Failed to add season'),
              seasons: state.seasons,
            ),
          ),
          (_) => emit(
            SeasonLoaded(
              seasons: state.seasons,
              successMessage: 'Season created',
            ),
          ),
        );
        return;
      }

      final currentSeasons = state.seasons;

      emit(SeasonLoading(seasons: currentSeasons));
      final result = await repository.addSeason(event.season);
      result.fold(
        (failure) => emit(SeasonError(
          resolveFailureMessage(failure, 'Failed to add season'),
          seasons: currentSeasons,
        )),
        (season) {
          final updatedSeasons = List<Season>.from(currentSeasons)..add(season);
          emit(SeasonLoaded(seasons: updatedSeasons, successMessage: 'Season created'));
        },
      );
    });

    on<UpdateSeasonEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await repository.updateSeason(event.season);
        result.fold(
          (failure) => emit(
            SeasonError(
              resolveFailureMessage(failure, 'Failed to update season'),
              seasons: state.seasons,
            ),
          ),
          (_) => emit(
            SeasonLoaded(
              seasons: state.seasons,
              successMessage: 'Season updated',
            ),
          ),
        );
        return;
      }

      final currentSeasons = state.seasons;

      emit(SeasonLoading(seasons: currentSeasons));
      final result = await repository.updateSeason(event.season);
      result.fold(
        (failure) => emit(SeasonError(
          resolveFailureMessage(failure, 'Failed to update season'),
          seasons: currentSeasons,
        )),
        (updatedSeason) {
          final updatedSeasons = currentSeasons.map((season) {
            return season.id == updatedSeason.id ? updatedSeason : season;
          }).toList();
          emit(SeasonLoaded(seasons: updatedSeasons, successMessage: 'Season updated'));
        },
      );
    });

    on<DeleteSeasonEvent>((event, emit) async {
      if (OfflineConfig.enabled) {
        final result = await repository.deleteSeason(event.id);
        result.fold(
          (failure) => emit(
            SeasonError(
              resolveFailureMessage(failure, 'Failed to delete season'),
              seasons: state.seasons,
            ),
          ),
          (_) => emit(
            SeasonLoaded(
              seasons: state.seasons,
              successMessage: 'Season deleted',
            ),
          ),
        );
        return;
      }

      final currentSeasons = state.seasons;

      emit(SeasonLoading(seasons: currentSeasons));
      final result = await repository.deleteSeason(event.id);
      result.fold(
        (failure) => emit(SeasonError(
          resolveFailureMessage(failure, 'Failed to delete season'),
          seasons: currentSeasons,
        )),
        (_) {
          final updatedSeasons = currentSeasons
              .where((season) => season.id != event.id)
              .toList();
          emit(SeasonLoaded(seasons: updatedSeasons, successMessage: 'Season deleted'));
        },
      );
    });
  }
  final SeasonRepository repository;

  StreamSubscription<List<Season>>? _seasonsSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMoreSeasonsEvent]: guards against a second
  /// page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  /// Fetches and APPENDS the next online page. No-op when offline, when the
  /// current loaded page already reached max, when there is no cursor to page
  /// from, or when a load-more is already running.
  Future<void> _onLoadMoreSeasons(
    LoadMoreSeasonsEvent event,
    Emitter<SeasonState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! SeasonLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getSeasons(
        limit: kOnlineListPageSize,
        cursor: current.nextCursor,
      );
      _isLoadingMore = false;
      result.fold(
        (failure) {
          if (state != current) return;
          emit(SeasonError(
            resolveFailureMessage(failure, 'Failed to load seasons'),
            seasons: current.seasons,
          ));
        },
        (more) {
          // A concurrent Add/Update/Delete/refresh emitted a newer state
          // while this fetch was in flight: drop this now-stale page rather
          // than clobbering it — the user's next scroll re-triggers
          // LoadMore against the fresh state.
          if (state != current) return;
          final combined = List<Season>.from(current.seasons)..addAll(more);
          emit(SeasonLoaded(
            seasons: combined,
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
  int? _cursorOf(List<Season> seasons) =>
      seasons.isEmpty ? null : int.tryParse(seasons.last.id);

  @override
  Future<void> close() async {
    await _seasonsSubscription?.cancel();
    return super.close();
  }
}
