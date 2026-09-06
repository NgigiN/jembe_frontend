import 'dart:async';

import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_infrastructure.dart';
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
  InfrastructureBloc({
    required this.getInfrastructure,
    required this.addInfrastructure,
    required this.updateInfrastructure,
    required this.deleteInfrastructure,
    required this.watchInfrastructure,
  }) : super(InfrastructureInitial()) {
    on<GetInfrastructuresEvent>(_onGetInfrastructures);
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

  final GetInfrastructure getInfrastructure;
  final AddInfrastructure addInfrastructure;
  final UpdateInfrastructure updateInfrastructure;
  final DeleteInfrastructure deleteInfrastructure;
  final WatchInfrastructure watchInfrastructure;

  StreamSubscription<List<Infrastructure>>? _infrastructuresSubscription;
  bool _watchStarted = false;

  Future<void> _onGetInfrastructures(
    GetInfrastructuresEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    emit(const InfrastructureLoading());
    final result = await getInfrastructure(NoParams());
    result.fold(
      (failure) => emit(InfrastructureError(
        resolveFailureMessage(failure, 'Failed to load infrastructure'),
      )),
      (list) => emit(InfrastructureLoaded(list)),
    );
  }

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
    _infrastructuresSubscription = watchInfrastructure().listen(
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
      final result = await addInfrastructure(
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
    final result = await addInfrastructure(
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
      final result = await updateInfrastructure(
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
    final result = await updateInfrastructure(
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
      final result = await deleteInfrastructure(event.id);
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
    final result = await deleteInfrastructure(event.id);
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
