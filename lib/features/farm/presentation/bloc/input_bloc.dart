import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_inputs.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_inputs_params.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_input.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_input.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_input.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_state.dart';

class InputBloc extends Bloc<InputEvent, InputState> {
  InputBloc({
    required this.getInputs,
    required this.addInput,
    required this.updateInput,
    required this.deleteInput,
  }) : super(InputInitial()) {
    on<GetInputsEvent>((event, emit) async {
      appLogger.debug(LogCategory.farm, 'GetInputsEvent triggered');
      emit(InputLoading());

      try {
        final result = await getInputs(
          GetInputsParams(sourceType: event.sourceType),
        );
        result.fold(
          (failure) {
            appLogger.warning(LogCategory.farm, 'GetInputs failed: $failure');
            String message = 'Failed to load inputs';
            if (failure is ServerFailure && failure.errorMessage != null) {
              message = failure.errorMessage!;
            }
            emit(InputError(message));
          },
          (inputs) {
            appLogger.info(LogCategory.farm, 'Loaded ${inputs.length} inputs');
            emit(InputLoaded(inputs: inputs));
          },
        );
      } catch (e) {
        appLogger.error(LogCategory.farm, 'GetInputs exception', e);
        emit(InputError('Unexpected error: $e'));
      }
    });

    on<AddInputEvent>((event, emit) async {
      final currentInputs = state.inputs;

      emit(InputLoading(inputs: currentInputs));
      final result = await addInput(AddInputParams(input: event.input));
      result.fold(
        (failure) {
          String message = 'Failed to add input';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(InputError(message, inputs: currentInputs));
        },
        (input) {
          final updatedInputs = List<Input>.from(currentInputs)..add(input);
          emit(InputLoaded(inputs: updatedInputs));
        },
      );
    });

    on<UpdateInputEvent>((event, emit) async {
      final currentInputs = state is InputLoaded
          ? (state as InputLoaded).inputs
          : <Input>[];

      emit(InputLoading());
      final result = await updateInput(UpdateInputParams(input: event.input));
      result.fold(
        (failure) {
          String message = 'Failed to update input';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(InputError(message, inputs: currentInputs));
        },
        (updatedInput) {
          final updatedInputs = currentInputs.map((input) {
            return input.id == updatedInput.id ? updatedInput : input;
          }).toList();
          emit(InputLoaded(inputs: updatedInputs));
        },
      );
    });

    on<DeleteInputEvent>((event, emit) async {
      final currentInputs = state is InputLoaded
          ? (state as InputLoaded).inputs
          : <Input>[];

      emit(InputLoading());
      final result = await deleteInput(DeleteInputParams(id: event.id));
      result.fold(
        (failure) {
          String message = 'Failed to delete input';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(InputError(message, inputs: currentInputs));
        },
        (_) {
          final updatedInputs = currentInputs
              .where((input) => input.id != event.id)
              .toList();
          emit(InputLoaded(inputs: updatedInputs));
        },
      );
    });
  }
  final GetInputs getInputs;
  final AddInput addInput;
  final UpdateInput updateInput;
  final DeleteInput deleteInput;
}
