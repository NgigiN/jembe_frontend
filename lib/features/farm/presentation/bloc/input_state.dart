import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';

abstract class InputState extends Equatable {
  const InputState({this.inputs = const []});
  final List<Input> inputs;

  @override
  List<Object> get props => [inputs];
}

class InputInitial extends InputState {}

class InputLoading extends InputState {
  const InputLoading({super.inputs});
}

class InputLoaded extends InputState {
  const InputLoaded({required super.inputs});

  @override
  List<Object> get props => [inputs];
}

class InputError extends InputState {
  const InputError(this.message, {super.inputs});
  final String message;

  @override
  List<Object> get props => [message, inputs];
}
