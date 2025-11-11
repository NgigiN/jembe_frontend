import 'package:equatable/equatable.dart';

abstract class FarmEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetLandsEvent extends FarmEvent {}

class AddLandEvent extends FarmEvent {
  final String name;
  final String soilType;
  final String location;
  final String size;
  AddLandEvent(this.name, this.soilType, this.location, this.size);

  @override
  List<Object> get props => [name, soilType, location, size];
}

class UpdateLandEvent extends FarmEvent {
  final String id;
  final String name;
  final String soilType;
  final String location;
  final String size;

  UpdateLandEvent(this.id, this.name, this.soilType, this.location, this.size);

  @override
  List<Object> get props => [id, name, soilType, location, size];
}

class DeleteLandEvent extends FarmEvent {
  final String id;
  DeleteLandEvent(this.id);

  @override
  List<Object> get props => [id];
}

class AddPlantEvent extends FarmEvent {
  final String name;
  final String variety;
  final String userId;
  AddPlantEvent(this.name, this.variety, this.userId);

  @override
  List<Object> get props => [name, variety, userId];
}

class GetPlantsEvent extends FarmEvent {}

class UpdatePlantEvent extends FarmEvent {
  final String id;
  final String name;
  final String variety;
  UpdatePlantEvent(this.id, this.name, this.variety);

  @override
  List<Object> get props => [id, name, variety];
}

class DeletePlantEvent extends FarmEvent {
  final String id;
  DeletePlantEvent(this.id);

  @override
  List<Object> get props => [id];
}

class GetSeasonsEvent extends FarmEvent {}

class AddSeasonEvent extends FarmEvent {
  final String name;
  final String landId;
  final String plantId;
  final String startDate;
  final String endDate;
  final String userId;
  AddSeasonEvent(
    this.name,
    this.landId,
    this.plantId,
    this.startDate,
    this.endDate,
    this.userId,
  );

  @override
  List<Object> get props => [name, landId, plantId, startDate, endDate, userId];
}

class UpdateSeasonEvent extends FarmEvent {
  final String id;
  final String name;
  final String landId;
  final String plantId;
  final String startDate;
  final String endDate;
  UpdateSeasonEvent(
    this.id,
    this.name,
    this.landId,
    this.plantId,
    this.startDate,
    this.endDate,
  );

  @override
  List<Object> get props => [id, name, landId, plantId, startDate, endDate];
}

class DeleteSeasonEvent extends FarmEvent {
  final String id;
  DeleteSeasonEvent(this.id);

  @override
  List<Object> get props => [id];
}

class GetActivitiesEvent extends FarmEvent {}

class AddActivityEvent extends FarmEvent {
  final String description;
  final String sourceType;
  final String sourceId;
  final int? animalId;
  final String type;
  final String date;
  final String details;
  final String? notes;
  final double cost;
  AddActivityEvent(
    this.description,
    this.sourceType,
    this.sourceId,
    this.animalId,
    this.type,
    this.date,
    this.details,
    this.notes,
    this.cost,
  );

  @override
  List<Object> get props => [
    description,
    sourceType,
    sourceId,
    animalId ?? 0,
    type,
    date,
    details,
    notes ?? '',
    cost,
  ];
}

class UpdateActivityEvent extends FarmEvent {
  final String id;
  final String description;
  final String sourceType;
  final String sourceId;
  final int? animalId;
  final String type;
  final String date;
  final String details;
  final String? notes;
  final double cost;
  UpdateActivityEvent(
    this.id,
    this.description,
    this.sourceType,
    this.sourceId,
    this.animalId,
    this.type,
    this.date,
    this.details,
    this.notes,
    this.cost,
  );

  @override
  List<Object> get props => [
    id,
    description,
    sourceType,
    sourceId,
    animalId ?? 0,
    type,
    date,
    details,
    notes ?? '',
    cost,
  ];
}

class DeleteActivityEvent extends FarmEvent {
  final String id;
  DeleteActivityEvent(this.id);

  @override
  List<Object> get props => [id];
}

class GetActivitiesBySeasonEvent extends FarmEvent {}

class GetInputsEvent extends FarmEvent {}

class AddInputEvent extends FarmEvent {
  final String sourceType;
  final String sourceId;
  final int? animalId;
  final String type;
  final double? quantity;
  final double cost;
  final String date;
  final String? notes;
  AddInputEvent(
    this.sourceType,
    this.sourceId,
    this.animalId,
    this.type,
    this.quantity,
    this.cost,
    this.date,
    this.notes,
  );

  @override
  List<Object> get props => [
    sourceType,
    sourceId,
    animalId ?? 0,
    type,
    quantity ?? 0.0,
    cost,
    date,
    notes ?? '',
  ];
}

class UpdateInputEvent extends FarmEvent {
  final String id;
  final String sourceType;
  final String sourceId;
  final int? animalId;
  final String type;
  final double? quantity;
  final double cost;
  final String date;
  final String? notes;
  UpdateInputEvent(
    this.id,
    this.sourceType,
    this.sourceId,
    this.animalId,
    this.type,
    this.quantity,
    this.cost,
    this.date,
    this.notes,
  );

  @override
  List<Object> get props => [
    id,
    sourceType,
    sourceId,
    animalId ?? 0,
    type,
    quantity ?? 0.0,
    cost,
    date,
    notes ?? '',
  ];
}

class DeleteInputEvent extends FarmEvent {
  final String id;
  DeleteInputEvent(this.id);

  @override
  List<Object> get props => [id];
}
