import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchRevenuesEvent` handler below listens to `watchRevenues()` (the
/// repository's UNFILTERED stream — see R1 doc on `WatchRevenuesEvent`) and
/// funnels every emission back through the bloc's own event queue via
/// `add(...)` instead of calling `emit` directly from the stream callback —
/// the standard bloc pattern for turning an external stream into state,
/// since `emit` is only valid while its owning `on<...>` handler is still
/// active.
class _RevenuesUpdated extends RevenueEvent {
  _RevenuesUpdated(this.revenues);
  final List<Revenue> revenues;

  @override
  List<Object> get props => [revenues];
}

/// Internal-only event: the `WatchRevenuesEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_RevenuesUpdated` — `emit` is only valid inside an active `on<...>`
/// handler, not from a raw stream callback). Non-fatal: it surfaces a
/// `RevenueError` over the last known (filtered) revenues snapshot rather
/// than crashing the bloc or dropping reactivity — the subscription is NOT
/// cancelled, so a later emission (if the underlying stream keeps going)
/// still comes through.
class _RevenuesWatchFailed extends RevenueEvent {
  _RevenuesWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class RevenueBloc extends Bloc<RevenueEvent, RevenueState> {

  RevenueBloc({required this.repository}) : super(RevenueInitial()) {
    on<LoadRevenues>(_onLoadRevenues);
    on<LoadMoreRevenuesEvent>(_onLoadMoreRevenues);
    on<WatchRevenuesEvent>(_onWatchRevenues);
    on<_RevenuesUpdated>((event, emit) {
      _allRevenues = event.revenues;
      emit(RevenueLoaded(revenues: _filtered()));
    });
    on<_RevenuesWatchFailed>((event, emit) {
      // Keeps the CURRENT state's list (not a re-derived `_filtered()`) —
      // mirrors `LandBloc`'s `_LandsWatchFailed` handler verbatim.
      emit(RevenueError(event.message, revenues: state.revenues));
    });
    on<AddRevenueEvent>(_onAddRevenue);
    on<UpdateRevenueEvent>(_onUpdateRevenue);
    on<DeleteRevenueEvent>(_onDeleteRevenue);
  }
  final RevenueRepository repository;

  StreamSubscription<List<Revenue>>? _revenuesSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMoreRevenuesEvent]: guards against a second
  /// page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  /// The full, UNFILTERED list from the last `watchRevenues()` emission —
  /// see R1: `RevenueBloc` is a singleton with a user-changeable filter, so
  /// a drift-level filtered watch would force a churny re-subscribe on every
  /// filter change. Instead this bloc caches the whole stream and filters
  /// it in memory (see [_filtered]) both on a fresh stream emission and on
  /// a filter-only change (no re-subscribe).
  List<Revenue> _allRevenues = const [];

  // The current source/date-range filter, seeded (and later updated) by
  // `WatchRevenuesEvent`'s args. Mirrors the server-side filter semantics
  // `RevenueRepositoryImpl`'s offline `getRevenues` branch uses: source
  // equality, date inclusive within [_startDate, _endDate].
  String? _source;
  DateTime? _startDate;
  DateTime? _endDate;

  List<Revenue> _filtered() {
    return _allRevenues.where((r) {
      if (_source != null && r.source != _source) return false;
      if (_startDate != null && r.date.isBefore(_startDate!)) return false;
      if (_endDate != null && r.date.isAfter(_endDate!)) return false;
      return true;
    }).toList();
  }

  Future<void> _onLoadRevenues(
    LoadRevenues event,
    Emitter<RevenueState> emit,
  ) async {
    emit(RevenueLoading(revenues: state.revenues));

    final result = await repository.getRevenues(
      source: event.source,
      startDate: event.startDate,
      endDate: event.endDate,
      limit: kOnlineListPageSize,
    );

    result.fold(
      (failure) {
        emit(RevenueError(
          resolveFailureMessage(failure, 'Failed to load revenues'),
          revenues: state.revenues,
        ));
      },
      (revenues) {
        // Online (flag off): this was page 1 of a cursor-paged list. Offline
        // returns the whole (filtered) local mirror in one shot, so it always
        // reaches max here and never pages.
        final online = !OfflineConfig.enabled;
        emit(RevenueLoaded(
          revenues: revenues,
          hasReachedMax:
              !online || revenues.length < kOnlineListPageSize,
          nextCursor: online ? _cursorOf(revenues) : null,
        ));
      },
    );
  }

  /// Fetches and APPENDS the next online page, re-applying the same
  /// source/date filter the current page was loaded with. No-op when offline,
  /// when the current loaded page already reached max, when there is no cursor
  /// to page from, or when a load-more is already running.
  Future<void> _onLoadMoreRevenues(
    LoadMoreRevenuesEvent event,
    Emitter<RevenueState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! RevenueLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getRevenues(
        source: event.source,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: kOnlineListPageSize,
        cursor: current.nextCursor,
      );
      _isLoadingMore = false;
      result.fold(
        (failure) {
          if (state != current) return;
          emit(RevenueError(
            resolveFailureMessage(failure, 'Failed to load revenues'),
            revenues: current.revenues,
          ));
        },
        (more) {
          // A concurrent Add/Update/Delete/refresh emitted a newer state
          // while this fetch was in flight: drop this now-stale page rather
          // than clobbering it — the user's next scroll re-triggers
          // LoadMore against the fresh state.
          if (state != current) return;
          final combined = List<Revenue>.from(current.revenues)..addAll(more);
          emit(RevenueLoaded(
            revenues: combined,
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
  int? _cursorOf(List<Revenue> revenues) =>
      revenues.isEmpty ? null : int.tryParse(revenues.last.id);

  // Synchronous handler, no `await` before the guard: dispatching
  // WatchRevenuesEvent twice in quick succession (e.g. initState + a
  // source-selector change) must never race and orphan a live subscription
  // — the guard makes every dispatch after the first update the in-memory
  // filter and re-emit from the cached list, WITHOUT ever re-subscribing.
  void _onWatchRevenues(
    WatchRevenuesEvent event,
    Emitter<RevenueState> emit,
  ) {
    _source = event.source;
    _startDate = event.startDate;
    _endDate = event.endDate;

    if (_watchStarted) {
      // The stream is already live: this is a filter change (or a no-op
      // re-dispatch) — re-emit from the cached full list, no re-subscribe.
      emit(RevenueLoaded(revenues: _filtered()));
      return;
    }

    _watchStarted = true;
    _revenuesSubscription = repository.watchRevenues().listen(
      (revenues) => add(_RevenuesUpdated(revenues)),
      onError: (Object error, StackTrace stackTrace) {
        appLogger.logError('RevenueBloc.watchRevenues', error, stackTrace);
        add(_RevenuesWatchFailed('Live sync interrupted. Pull to refresh.'));
      },
      onDone: () {
        appLogger.info(
          LogCategory.farm,
          'RevenueBloc.watchRevenues stream completed',
        );
      },
    );
  }

  Future<void> _onAddRevenue(
    AddRevenueEvent event,
    Emitter<RevenueState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.addRevenue(
        source: event.source,
        sourceId: event.sourceId,
        type: event.type,
        quantity: event.quantity,
        unitPrice: event.unitPrice,
        total: event.total,
        date: event.date,
        notes: event.notes,
      );

      result.fold(
        (failure) {
          emit(RevenueError(
            resolveFailureMessage(failure, 'Failed to add revenue'),
            revenues: state.revenues,
          ));
        },
        (revenue) {
          // NO manual append — the watch stream (still subscribed; the
          // local upsert this write staged will land in its next emission)
          // refreshes `state.revenues`. Only the distinct ack state and the
          // offline-built model change here.
          emit(RevenueAdded(revenue: revenue, revenues: state.revenues));
        },
      );
      return;
    }

    final currentRevenues = state.revenues;
    emit(RevenueLoading(revenues: currentRevenues));

    final result = await repository.addRevenue(
      source: event.source,
      sourceId: event.sourceId,
      type: event.type,
      quantity: event.quantity,
      unitPrice: event.unitPrice,
      total: event.total,
      date: event.date,
      notes: event.notes,
    );

    result.fold(
      (failure) {
        emit(RevenueError(
          resolveFailureMessage(failure, 'Failed to add revenue'),
          revenues: currentRevenues,
        ));
      },
      (revenue) {
        final updatedList = List<Revenue>.from(currentRevenues)..add(revenue);
        emit(RevenueAdded(revenue: revenue, revenues: updatedList));
      },
    );
  }

  Future<void> _onUpdateRevenue(
    UpdateRevenueEvent event,
    Emitter<RevenueState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.updateRevenue(
        id: event.id,
        source: event.source,
        sourceId: event.sourceId,
        type: event.type,
        quantity: event.quantity,
        unitPrice: event.unitPrice,
        total: event.total,
        date: event.date,
        notes: event.notes,
      );

      result.fold(
        (failure) {
          emit(RevenueError(
            resolveFailureMessage(failure, 'Failed to update revenue'),
            revenues: state.revenues,
          ));
        },
        (revenue) {
          // NO manual list replace — the watch stream refreshes
          // `state.revenues`.
          emit(RevenueUpdated(revenue: revenue, revenues: state.revenues));
        },
      );
      return;
    }

    final currentRevenues = state.revenues;
    emit(RevenueLoading(revenues: currentRevenues));

    final result = await repository.updateRevenue(
      id: event.id,
      source: event.source,
      sourceId: event.sourceId,
      type: event.type,
      quantity: event.quantity,
      unitPrice: event.unitPrice,
      total: event.total,
      date: event.date,
      notes: event.notes,
    );

    result.fold(
      (failure) {
        emit(RevenueError(
          resolveFailureMessage(failure, 'Failed to update revenue'),
          revenues: currentRevenues,
        ));
      },
      (revenue) {
        final updatedList = List<Revenue>.from(currentRevenues);
        final index = updatedList.indexWhere((r) => r.id == revenue.id);
        if (index != -1) {
          updatedList[index] = revenue;
        }
        emit(RevenueUpdated(revenue: revenue, revenues: updatedList));
      },
    );
  }

  Future<void> _onDeleteRevenue(
    DeleteRevenueEvent event,
    Emitter<RevenueState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.deleteRevenue(event.id);

      result.fold(
        (failure) {
          emit(RevenueError(
            resolveFailureMessage(failure, 'Failed to delete revenue'),
            revenues: state.revenues,
          ));
        },
        (_) {
          // NO manual removeWhere — the watch stream refreshes
          // `state.revenues`.
          emit(RevenueDeleted(revenues: state.revenues));
        },
      );
      return;
    }

    final currentRevenues = state.revenues;
    emit(RevenueLoading(revenues: currentRevenues));

    final result = await repository.deleteRevenue(event.id);

    result.fold(
      (failure) {
        emit(RevenueError(
          resolveFailureMessage(failure, 'Failed to delete revenue'),
          revenues: currentRevenues,
        ));
      },
      (_) {
        final updatedList = List<Revenue>.from(currentRevenues)
          ..removeWhere((r) => r.id == event.id);
        emit(RevenueDeleted(revenues: updatedList));
      },
    );
  }

  @override
  Future<void> close() async {
    await _revenuesSubscription?.cancel();
    return super.close();
  }
}
