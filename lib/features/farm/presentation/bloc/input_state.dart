import 'package:equatable/equatable.dart';
import '../../domain/entities/input.dart';

abstract class InputState extends Equatable {
  final List<Input> inputs;

  const InputState({this.inputs = const []});

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
  final String message;

  const InputError(this.message, {super.inputs});

  @override
  List<Object> get props => [message, inputs];
}
