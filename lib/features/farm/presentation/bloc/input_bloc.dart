import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/input.dart';
import '../../domain/usecases/get_inputs.dart';
import '../../domain/usecases/get_inputs_params.dart';
import '../../domain/usecases/add_input.dart';
import '../bloc/input_event.dart';
import '../bloc/input_state.dart';

class InputBloc extends Bloc<InputEvent, InputState> {
  final GetInputs getInputs;
  final AddInput addInput;

  InputBloc({required this.getInputs, required this.addInput})
    : super(InputInitial()) {
    on<GetInputsEvent>((event, emit) async {
      print('GetInputsEvent triggered');
      emit(InputLoading());

      try {
        final result = await getInputs(
          GetInputsParams(sourceType: event.sourceType),
        );
        result.fold(
          (failure) {
            print('GetInputs failed: $failure');
            String message = 'Failed to load inputs';
            if (failure is ServerFailure && failure.errorMessage != null) {
              message = failure.errorMessage!;
            }
            emit(InputError(message));
          },
          (inputs) {
            print('GetInputs success: ${inputs.length} inputs loaded');
            emit(InputLoaded(inputs: inputs));
          },
        );
      } catch (e) {
        print('GetInputs exception: $e');
        emit(InputError('Unexpected error: $e'));
      }
    });

    on<AddInputEvent>((event, emit) async {
      // Store current inputs before emitting loading state
      final currentInputs = state is InputLoaded
          ? (state as InputLoaded).inputs
          : <Input>[];

      emit(InputLoading());
      final result = await addInput(AddInputParams(input: event.input));
      result.fold(
        (failure) {
          String message = 'Failed to add input';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(InputError(message));
        },
        (input) {
          final updatedInputs = List<Input>.from(currentInputs)..add(input);
          emit(InputLoaded(inputs: updatedInputs));
        },
      );
    });
  }
}
