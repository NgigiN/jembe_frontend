import 'package:equatable/equatable.dart';

abstract class AnimalTypeEvent extends Equatable {
  const AnimalTypeEvent();

  @override
  List<Object?> get props => [];
}

class GetAnimalTypesEvent extends AnimalTypeEvent {}

class AddAnimalTypeEvent extends AnimalTypeEvent {
  final String name;
  final String? notes;
  final String userId;

  const AddAnimalTypeEvent(this.name, this.notes, this.userId);

  @override
  List<Object?> get props => [name, notes, userId];
}

class UpdateAnimalTypeEvent extends AnimalTypeEvent {
  final String id;
  final String name;
  final String? notes;

  const UpdateAnimalTypeEvent(this.id, this.name, this.notes);

  @override
  List<Object?> get props => [id, name, notes];
}

class DeleteAnimalTypeEvent extends AnimalTypeEvent {
  final String id;

  const DeleteAnimalTypeEvent(this.id);

  @override
  List<Object?> get props => [id];
}

