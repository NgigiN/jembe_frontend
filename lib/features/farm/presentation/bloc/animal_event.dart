import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

abstract class AnimalEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetAnimalsEvent extends AnimalEvent {}

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
