import 'package:equatable/equatable.dart';
import '../../domain/entities/input.dart';

abstract class InputEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetInputsEvent extends InputEvent {}

class AddInputEvent extends InputEvent {
  final Input input;

  AddInputEvent(this.input);

  @override
  List<Object> get props => [input];
}
