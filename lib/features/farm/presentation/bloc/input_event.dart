import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';

abstract class InputEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetInputsEvent extends InputEvent {
  GetInputsEvent({this.sourceType});
  final String? sourceType;

  @override
  List<Object> get props => [sourceType ?? ''];
}

/// Flag-ON only: subscribes (or re-subscribes) `InputBloc` to
/// `repository.watchInputs(sourceType:)`, scoped exactly like the existing
/// `GetInputsEvent(sourceType:)`. Every subsequent stream emission is turned
/// into an `InputLoaded(inputs: ...)` state — see `InputBloc`'s internal
/// `_InputsUpdated` event for how.
class WatchInputsEvent extends InputEvent {
  WatchInputsEvent({this.sourceType});
  final String? sourceType;

  @override
  List<Object> get props => [sourceType ?? ''];
}

class AddInputEvent extends InputEvent {
  AddInputEvent(this.input);
  final Input input;

  @override
  List<Object> get props => [input];
}

class UpdateInputEvent extends InputEvent {
  UpdateInputEvent(this.input);
  final Input input;

  @override
  List<Object> get props => [input];
}

class DeleteInputEvent extends InputEvent {
  DeleteInputEvent(this.id);
  final String id;

  @override
  List<Object> get props => [id];
}
