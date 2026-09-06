import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

abstract class AnimalEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetAnimalsEvent extends AnimalEvent {}

/// Flag-ON only: subscribes (or re-subscribes) `AnimalBloc` to
/// `repository.watchAnimals()`. Every subsequent stream emission is turned
/// into an `AnimalLoaded(animals: ...)` state — see `AnimalBloc`'s internal
/// `_AnimalsUpdated` event for how.
class WatchAnimalsEvent extends AnimalEvent {}

class AddAnimalEvent extends AnimalEvent {
  AddAnimalEvent(this.animal);
  final Animal animal;

  @override
  List<Object> get props => [animal];
}

class UpdateAnimalEvent extends AnimalEvent {
  UpdateAnimalEvent(this.animal);
  final Animal animal;

  @override
  List<Object> get props => [animal];
}

class DeleteAnimalEvent extends AnimalEvent {
  DeleteAnimalEvent(this.id);
  final String id;

  @override
  List<Object> get props => [id];
}
