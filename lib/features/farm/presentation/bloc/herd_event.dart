import 'package:equatable/equatable.dart';

abstract class HerdEvent extends Equatable {
  const HerdEvent();

  @override
  List<Object?> get props => [];
}

class GetHerdsEvent extends HerdEvent {}

class AddHerdEvent extends HerdEvent {
  const AddHerdEvent(
    this.name,
    this.animalTypeId,
    this.location,
    this.userId,
    this.initialHeadCount, {
    required this.startDate,
    this.endDate,
  });
  final String name;
  final String animalTypeId;
  final String location;
  final String userId;
  final int initialHeadCount;
  final DateTime startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [
    name,
    animalTypeId,
    location,
    userId,
    initialHeadCount,
    startDate,
    endDate,
  ];
}

class UpdateHerdEvent extends HerdEvent {
  const UpdateHerdEvent(
    this.id,
    this.name,
    this.animalTypeId,
    this.location,
    this.initialHeadCount, {
    required this.startDate,
    this.endDate,
  });
  final String id;
  final String name;
  final String animalTypeId;
  final String location;
  final int initialHeadCount;
  final DateTime startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [
    id,
    name,
    animalTypeId,
    location,
    initialHeadCount,
    startDate,
    endDate,
  ];
}

class DeleteHerdEvent extends HerdEvent {
  const DeleteHerdEvent(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
