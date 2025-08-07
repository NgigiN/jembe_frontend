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

class AddCropEvent extends FarmEvent {
  final String name;
  final String variety;
  final String userId;
  AddCropEvent(this.name, this.variety, this.userId);

  @override
  List<Object> get props => [name, variety, userId];
}

class GetCropsEvent extends FarmEvent {}

class UpdateCropEvent extends FarmEvent {
  final String id;
  final String name;
  final String variety;
  UpdateCropEvent(this.id, this.name, this.variety);

  @override
  List<Object> get props => [id, name, variety];
}

class GetSeasonsEvent extends FarmEvent {}

class AddSeasonEvent extends FarmEvent {
  final String name;
  final String landId;
  final String cropId;
  final String startDate;
  final String endDate;
  final String userId;
  AddSeasonEvent(
    this.name,
    this.landId,
    this.cropId,
    this.startDate,
    this.endDate,
    this.userId,
  );

  @override
  List<Object> get props => [name, landId, cropId, startDate, endDate, userId];
}

class GetActivitiesEvent extends FarmEvent {}

class AddActivityEvent extends FarmEvent {
  final String description;
  final String seasonId;
  final String type;
  final String date;
  final String details;
  AddActivityEvent(
    this.description,
    this.seasonId,
    this.type,
    this.date,
    this.details,
  );

  @override
  List<Object> get props => [description, seasonId, type, date, details];
}

class GetActivitiesBySeasonEvent extends FarmEvent {}

class GetInputsEvent extends FarmEvent {}

class AddInputEvent extends FarmEvent {
  final String seasonId;
  final String type;
  final double? quantity;
  final double cost;
  final String date;
  final String? notes;
  AddInputEvent(
    this.seasonId,
    this.type,
    this.quantity,
    this.cost,
    this.date,
    this.notes,
  );

  @override
  List<Object> get props => [
    seasonId,
    type,
    quantity ?? 0.0,
    cost,
    date,
    notes ?? '',
  ];
}
