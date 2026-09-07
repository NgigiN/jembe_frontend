import 'dart:async';

import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchInfrastructureEvent` handler below listens to
/// `watchInfrastructures()` and funnels every emission back through the
/// bloc's own event queue via `add(...)` instead of calling `emit` directly
/// from the stream callback — the standard bloc pattern for turning an
/// external stream into state, since `emit` is only valid while its owning
/// `on<...>` handler is still active.
class _InfrastructuresUpdated extends InfrastructureEvent {
  _InfrastructuresUpdated(this.infrastructures);
  final List<Infrastructure> infrastructures;

  @override
  List<Object> get props => [infrastructures];
}

/// Internal-only event: the `WatchInfrastructureEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_InfrastructuresUpdated` — `emit` is only valid inside an active
/// `on<...>` handler, not from a raw stream callback). Non-fatal: it
/// surfaces an `InfrastructureError` over the last known `infrastructures`
/// snapshot rather than crashing the bloc or dropping reactivity — the
/// subscription is NOT cancelled, so a later emission (if the underlying
/// stream keeps going) still comes through.
class _InfrastructuresWatchFailed extends InfrastructureEvent {
  _InfrastructuresWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class InfrastructureBloc extends Bloc<InfrastructureEvent, InfrastructureState> {
  InfrastructureBloc({required this.repository}) : super(InfrastructureInitial()) {
    on<GetInfrastructuresEvent>(_onGetInfrastructures);
    on<LoadMoreInfrastructuresEvent>(_onLoadMoreInfrastructures);
    on<WatchInfrastructureEvent>(_onWatchInfrastructures);
    on<_InfrastructuresUpdated>((event, emit) {
      emit(InfrastructureLoaded(event.infrastructures));
    });
    on<_InfrastructuresWatchFailed>((event, emit) {
      emit(
        InfrastructureError(event.message, infrastructures: state.infrastructures),
      );
    });
    on<AddInfrastructureEvent>(_onAddInfrastructure);
    on<UpdateInfrastructureEvent>(_onUpdateInfrastructure);
    on<DeleteInfrastructureEvent>(_onDeleteInfrastructure);
  }

  final InfrastructureRepository repository;

  StreamSubscription<List<Infrastructure>>? _infrastructuresSubscription;
  bool _watchStarted = false;

  /// Concurrency latch for [LoadMoreInfrastructuresEvent]: guards against a
  /// second page fetch starting while the first is still in flight.
  bool _isLoadingMore = false;

  Future<void> _onGetInfrastructures(
    GetInfrastructuresEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    emit(const InfrastructureLoading());
    final result = await repository.getInfrastructures(
      limit: kOnlineListPageSize,
    );
    result.fold(
      (failure) => emit(InfrastructureError(
        resolveFailureMessage(failure, 'Failed to load infrastructure'),
      )),
      (list) {
        // Online (flag off): this was page 1 of a cursor-paged list.
        // Offline returns the whole local mirror in one shot, so it always
        // reaches max here and never pages.
        final online = !OfflineConfig.enabled;
        emit(InfrastructureLoaded(
          list,
          hasReachedMax: !online || list.length < kOnlineListPageSize,
          nextCursor: online ? _cursorOf(list) : null,
        ));
      },
    );
  }

  /// Fetches and APPENDS the next online page. No-op when offline, when the
  /// current loaded page already reached max, when there is no cursor to page
  /// from, or when a load-more is already running.
  Future<void> _onLoadMoreInfrastructures(
    LoadMoreInfrastructuresEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    if (OfflineConfig.enabled) return;
    final current = state;
    if (current is! InfrastructureLoaded) return;
    if (current.hasReachedMax ||
        current.nextCursor == null ||
        _isLoadingMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final result = await repository.getInfrastructures(
        limit: kOnlineListPageSize,
        cursor: current.nextCursor,
      );
      _isLoadingMore = false;
      result.fold(
        (failure) {
          if (state != current) return;
          emit(InfrastructureError(
            resolveFailureMessage(failure, 'Failed to load infrastructure'),
            infrastructures: current.infrastructures,
          ));
        },
        (more) {
          // A concurrent Add/Update/Delete/refresh emitted a newer state
          // while this fetch was in flight: drop this now-stale page rather
          // than clobbering it — the user's next scroll re-triggers
          // LoadMore against the fresh state.
          if (state != current) return;
          final combined = List<Infrastructure>.from(current.infrastructures)
            ..addAll(more);
          emit(InfrastructureLoaded(
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
  int? _cursorOf(List<Infrastructure> infrastructures) => infrastructures.isEmpty
      ? null
      : int.tryParse(infrastructures.last.id);

  void _onWatchInfrastructures(
    WatchInfrastructureEvent event,
    Emitter<InfrastructureState> emit,
  ) {
    // Synchronous handler, no `await` before the guard: dispatching
    // WatchInfrastructureEvent twice in quick succession (e.g. initState +
    // pull-to-refresh) must never race and orphan a live subscription — the
    // guard makes the second (and every subsequent) dispatch a pure no-op
    // instead.
    if (_watchStarted) return;
    _watchStarted = true;
    _infrastructuresSubscription = repository.watchInfrastructures().listen(
      (infrastructures) => add(_InfrastructuresUpdated(infrastructures)),
      onError: (Object error, StackTrace stackTrace) {
        appLogger.logError(
          'InfrastructureBloc.watchInfrastructure',
          error,
          stackTrace,
        );
        add(
          _InfrastructuresWatchFailed('Live sync interrupted. Pull to refresh.'),
        );
      },
      onDone: () {
        appLogger.info(
          LogCategory.farm,
          'InfrastructureBloc.watchInfrastructure stream completed',
        );
      },
    );
  }

  Future<void> _onAddInfrastructure(
    AddInfrastructureEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.addInfrastructure(
        event.type,
        event.name,
        event.location,
        event.cost,
        event.date,
        event.userId,
        event.notes,
      );
      result.fold(
        (failure) => emit(InfrastructureError(
          resolveFailureMessage(failure, 'Failed to add infrastructure'),
          infrastructures: state.infrastructures,
        )),
        (_) => emit(
          InfrastructureLoaded(
            state.infrastructures,
            successMessage: 'Infrastructure added',
          ),
        ),
      );
      return;
    }

    final currentList = state.infrastructures;
    emit(InfrastructureLoading(infrastructures: currentList));
    final result = await repository.addInfrastructure(
      event.type,
      event.name,
      event.location,
      event.cost,
      event.date,
      event.userId,
      event.notes,
    );
    result.fold(
      (failure) => emit(InfrastructureError(
        resolveFailureMessage(failure, 'Failed to add infrastructure'),
        infrastructures: currentList,
      )),
      (item) {
        final updatedList = List<Infrastructure>.from(currentList)..add(item);
        emit(InfrastructureLoaded(updatedList, successMessage: 'Infrastructure added'));
      },
    );
  }

  Future<void> _onUpdateInfrastructure(
    UpdateInfrastructureEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.updateInfrastructure(
        event.id,
        event.type,
        event.name,
        event.location,
        event.cost,
        event.date,
        event.notes,
      );
      result.fold(
        (failure) => emit(InfrastructureError(
          resolveFailureMessage(failure, 'Failed to update infrastructure'),
          infrastructures: state.infrastructures,
        )),
        (_) => emit(
          InfrastructureLoaded(
            state.infrastructures,
            successMessage: 'Infrastructure updated',
          ),
        ),
      );
      return;
    }

    final currentList = state.infrastructures;
    emit(InfrastructureLoading(infrastructures: currentList));
    final result = await repository.updateInfrastructure(
      event.id,
      event.type,
      event.name,
      event.location,
      event.cost,
      event.date,
      event.notes,
    );
    result.fold(
      (failure) => emit(InfrastructureError(
        resolveFailureMessage(failure, 'Failed to update infrastructure'),
        infrastructures: currentList,
      )),
      (updatedItem) {
        final updatedList = currentList.map((item) {
          return item.id == updatedItem.id ? updatedItem : item;
        }).toList();
        emit(InfrastructureLoaded(updatedList, successMessage: 'Infrastructure updated'));
      },
    );
  }

  Future<void> _onDeleteInfrastructure(
    DeleteInfrastructureEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.deleteInfrastructure(event.id);
      result.fold(
        (failure) => emit(InfrastructureError(
          resolveFailureMessage(failure, 'Failed to delete infrastructure'),
          infrastructures: state.infrastructures,
        )),
        (_) => emit(
          InfrastructureLoaded(
            state.infrastructures,
            successMessage: 'Infrastructure deleted',
          ),
        ),
      );
      return;
    }

    final currentList = state.infrastructures;
    emit(InfrastructureLoading(infrastructures: currentList));
    final result = await repository.deleteInfrastructure(event.id);
    result.fold(
      (failure) => emit(InfrastructureError(
        resolveFailureMessage(failure, 'Failed to delete infrastructure'),
        infrastructures: currentList,
      )),
      (_) {
        final updatedList = currentList.where((item) => item.id != event.id).toList();
        emit(InfrastructureLoaded(updatedList, successMessage: 'Infrastructure deleted'));
      },
    );
  }

  @override
  Future<void> close() async {
    await _infrastructuresSubscription?.cancel();
    return super.close();
  }
}
