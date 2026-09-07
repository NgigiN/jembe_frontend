import 'dart:async';

import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchInputsEvent` handler below listens to `watchInputs(sourceType:)`
/// and funnels every emission back through the bloc's own event queue via
/// `add(...)` instead of calling `emit` directly from the stream callback —
/// the standard bloc pattern for turning an external stream into state,
/// since `emit` is only valid while its owning `on<...>` handler is still
/// active.
class _InputsUpdated extends InputEvent {
  _InputsUpdated(this.inputs);
  final List<Input> inputs;

  @override
  List<Object> get props => [inputs];
}

/// Internal-only event: the `WatchInputsEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_InputsUpdated` — `emit` is only valid inside an active `on<...>`
/// handler, not from a raw stream callback). Non-fatal: it surfaces an
/// `InputError` over the last known `inputs` snapshot rather than crashing
/// the bloc or dropping reactivity — the subscription is NOT cancelled, so
/// a later emission (if the underlying stream keeps going) still comes
/// through.
class _InputsWatchFailed extends InputEvent {
  _InputsWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class InputBloc extends Bloc<InputEvent, InputState> {
  InputBloc({required this.repository}) : super(InputInitial()) {
    on<GetInputsEvent>(_onGetInputs);
    on<WatchInputsEvent>(_onWatchInputs);
    on<_InputsUpdated>((event, emit) {
      emit(InputLoaded(inputs: event.inputs));
    });
    on<_InputsWatchFailed>((event, emit) {
      emit(InputError(event.message, inputs: state.inputs));
    });
    on<AddInputEvent>(_onAddInput);
    on<UpdateInputEvent>(_onUpdateInput);
    on<DeleteInputEvent>(_onDeleteInput);
  }

  final InputRepository repository;

  StreamSubscription<List<Input>>? _inputsSubscription;
  bool _watchStarted = false;

  Future<void> _onGetInputs(
    GetInputsEvent event,
    Emitter<InputState> emit,
  ) async {
    appLogger.debug(LogCategory.farm, 'GetInputsEvent triggered');
    emit(const InputLoading());

    final result = await repository.getInputs(sourceType: event.sourceType);
    result.fold(
      (failure) {
        appLogger.warning(LogCategory.farm, 'GetInputs failed: $failure');
        emit(InputError(resolveFailureMessage(failure, 'Failed to load inputs')));
      },
      (inputs) {
        appLogger.info(LogCategory.farm, 'Loaded ${inputs.length} inputs');
        emit(InputLoaded(inputs: inputs));
      },
    );
  }

  // Synchronous handler, no `await` before the guard: dispatching
  // WatchInputsEvent twice in quick succession (e.g. initState +
  // pull-to-refresh) must never race and orphan a live subscription — the
  // guard makes the second (and every subsequent) dispatch a pure no-op
  // instead.
  void _onWatchInputs(
    WatchInputsEvent event,
    Emitter<InputState> emit,
  ) {
    if (_watchStarted) return;
    _watchStarted = true;
    _inputsSubscription = repository.watchInputs(sourceType: event.sourceType).listen(
      (inputs) => add(_InputsUpdated(inputs)),
      onError: (Object error, StackTrace stackTrace) {
        appLogger.logError('InputBloc.watchInputs', error, stackTrace);
        add(_InputsWatchFailed('Live sync interrupted. Pull to refresh.'));
      },
      onDone: () {
        appLogger.info(
          LogCategory.farm,
          'InputBloc.watchInputs stream completed',
        );
      },
    );
  }

  Future<void> _onAddInput(
    AddInputEvent event,
    Emitter<InputState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.addInput(event.input);
      result.fold(
        (failure) => emit(InputError(
          resolveFailureMessage(failure, 'Failed to add input'),
          inputs: state.inputs,
        )),
        (_) => emit(
          InputLoaded(inputs: state.inputs, successMessage: 'Input added'),
        ),
      );
      return;
    }

    final currentInputs = state.inputs;
    emit(InputLoading(inputs: currentInputs));
    final result = await repository.addInput(event.input);
    result.fold(
      (failure) => emit(InputError(
        resolveFailureMessage(failure, 'Failed to add input'),
        inputs: currentInputs,
      )),
      (input) {
        final updatedInputs = List<Input>.from(currentInputs)..add(input);
        emit(InputLoaded(inputs: updatedInputs, successMessage: 'Input added'));
      },
    );
  }

  Future<void> _onUpdateInput(
    UpdateInputEvent event,
    Emitter<InputState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.updateInput(event.input);
      result.fold(
        (failure) => emit(InputError(
          resolveFailureMessage(failure, 'Failed to update input'),
          inputs: state.inputs,
        )),
        (_) => emit(
          InputLoaded(inputs: state.inputs, successMessage: 'Input updated'),
        ),
      );
      return;
    }

    final currentInputs = state.inputs;
    emit(InputLoading(inputs: currentInputs));
    final result = await repository.updateInput(event.input);
    result.fold(
      (failure) => emit(InputError(
        resolveFailureMessage(failure, 'Failed to update input'),
        inputs: currentInputs,
      )),
      (updatedInput) {
        final updatedInputs = currentInputs.map((input) {
          return input.id == updatedInput.id ? updatedInput : input;
        }).toList();
        emit(InputLoaded(inputs: updatedInputs, successMessage: 'Input updated'));
      },
    );
  }

  Future<void> _onDeleteInput(
    DeleteInputEvent event,
    Emitter<InputState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await repository.deleteInput(event.id);
      result.fold(
        (failure) => emit(InputError(
          resolveFailureMessage(failure, 'Failed to delete input'),
          inputs: state.inputs,
        )),
        (_) => emit(
          InputLoaded(inputs: state.inputs, successMessage: 'Input deleted'),
        ),
      );
      return;
    }

    final currentInputs = state.inputs;
    emit(InputLoading(inputs: currentInputs));
    final result = await repository.deleteInput(event.id);
    result.fold(
      (failure) => emit(InputError(
        resolveFailureMessage(failure, 'Failed to delete input'),
        inputs: currentInputs,
      )),
      (_) {
        final updatedInputs = currentInputs
            .where((input) => input.id != event.id)
            .toList();
        emit(InputLoaded(inputs: updatedInputs, successMessage: 'Input deleted'));
      },
    );
  }

  @override
  Future<void> close() async {
    await _inputsSubscription?.cancel();
    return super.close();
  }
}
