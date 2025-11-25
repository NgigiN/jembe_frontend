import 'package:equatable/equatable.dart';

abstract class HerdEvent extends Equatable {
  const HerdEvent();

  @override
  List<Object?> get props => [];
}

class GetHerdsEvent extends HerdEvent {}

class AddHerdEvent extends HerdEvent {
  final String name;
  final String animalTypeId;
  final String location;
  final String userId;

  const AddHerdEvent(this.name, this.animalTypeId, this.location, this.userId);

  @override
  List<Object?> get props => [name, animalTypeId, location, userId];
}

class UpdateHerdEvent extends HerdEvent {
  final String id;
  final String name;
  final String animalTypeId;
  final String location;

  const UpdateHerdEvent(this.id, this.name, this.animalTypeId, this.location);

  @override
  List<Object?> get props => [id, name, animalTypeId, location];
}

class DeleteHerdEvent extends HerdEvent {
  final String id;

  const DeleteHerdEvent(this.id);

  @override
  List<Object?> get props => [id];
}

