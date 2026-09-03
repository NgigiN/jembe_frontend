import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_input.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_input.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_inputs.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_inputs_params.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_input.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InputBloc extends Bloc<InputEvent, InputState> {
  InputBloc({
    required this.getInputs,
    required this.addInput,
    required this.updateInput,
    required this.deleteInput,
  }) : super(InputInitial()) {
    on<GetInputsEvent>((event, emit) async {
      appLogger.debug(LogCategory.farm, 'GetInputsEvent triggered');
      emit(const InputLoading());

      final result = await getInputs(
        GetInputsParams(sourceType: event.sourceType),
      );
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
    });

    on<AddInputEvent>((event, emit) async {
      final currentInputs = state.inputs;

      emit(InputLoading(inputs: currentInputs));
      final result = await addInput(AddInputParams(input: event.input));
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
    });

    on<UpdateInputEvent>((event, emit) async {
      final currentInputs = state.inputs;

      emit(InputLoading(inputs: currentInputs));
      final result = await updateInput(UpdateInputParams(input: event.input));
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
    });

    on<DeleteInputEvent>((event, emit) async {
      final currentInputs = state.inputs;

      emit(InputLoading(inputs: currentInputs));
      final result = await deleteInput(DeleteInputParams(id: event.id));
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
    });
  }
  final GetInputs getInputs;
  final AddInput addInput;
  final UpdateInput updateInput;
  final DeleteInput deleteInput;
}
