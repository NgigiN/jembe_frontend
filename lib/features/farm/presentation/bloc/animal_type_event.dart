import 'package:equatable/equatable.dart';

abstract class AnimalTypeEvent extends Equatable {
  const AnimalTypeEvent();

  @override
  List<Object?> get props => [];
}

class GetAnimalTypesEvent extends AnimalTypeEvent {}

class AddAnimalTypeEvent extends AnimalTypeEvent {
  const AddAnimalTypeEvent(this.name, this.notes, this.userId);
  final String name;
  final String? notes;
  final String userId;

  @override
  List<Object?> get props => [name, notes, userId];
}

class UpdateAnimalTypeEvent extends AnimalTypeEvent {
  const UpdateAnimalTypeEvent(this.id, this.name, this.notes);
  final String id;
  final String name;
  final String? notes;

  @override
  List<Object?> get props => [id, name, notes];
}

class DeleteAnimalTypeEvent extends AnimalTypeEvent {
  const DeleteAnimalTypeEvent(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
