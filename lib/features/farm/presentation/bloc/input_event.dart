import 'package:equatable/equatable.dart';
import '../../domain/entities/input.dart';

abstract class InputEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetInputsEvent extends InputEvent {
  final String? sourceType;

  GetInputsEvent({this.sourceType});

  @override
  List<Object> get props => [sourceType ?? ''];
}

class AddInputEvent extends InputEvent {
  final Input input;

  AddInputEvent(this.input);

  @override
  List<Object> get props => [input];
}

class UpdateInputEvent extends InputEvent {
  final Input input;

  UpdateInputEvent(this.input);

  @override
  List<Object> get props => [input];
}

class DeleteInputEvent extends InputEvent {
  final String id;

  DeleteInputEvent(this.id);

  @override
  List<Object> get props => [id];
}
