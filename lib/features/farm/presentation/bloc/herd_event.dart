import 'package:equatable/equatable.dart';

abstract class HerdEvent extends Equatable {
  const HerdEvent();

  @override
  List<Object?> get props => [];
}

class GetHerdsEvent extends HerdEvent {}

class AddHerdEvent extends HerdEvent {
  const AddHerdEvent(this.name, this.animalTypeId, this.location, this.userId);
  final String name;
  final String animalTypeId;
  final String location;
  final String userId;

  @override
  List<Object?> get props => [name, animalTypeId, location, userId];
}

class UpdateHerdEvent extends HerdEvent {
  const UpdateHerdEvent(this.id, this.name, this.animalTypeId, this.location);
  final String id;
  final String name;
  final String animalTypeId;
  final String location;

  @override
  List<Object?> get props => [id, name, animalTypeId, location];
}

class DeleteHerdEvent extends HerdEvent {
  const DeleteHerdEvent(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
