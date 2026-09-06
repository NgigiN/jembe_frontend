import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';

abstract class PlantEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetPlantsEvent extends PlantEvent {}

/// Flag-ON only: subscribes (or re-subscribes) `PlantBloc` to
/// `repository.watchPlants()`. Every subsequent stream emission is turned
/// into a `PlantLoaded(plants: ...)` state — see `PlantBloc`'s internal
/// `_PlantsUpdated` event for how.
class WatchPlantsEvent extends PlantEvent {}

class AddPlantEvent extends PlantEvent {
  AddPlantEvent(this.plant);
  final Plant plant;

  @override
  List<Object> get props => [plant];
}

class UpdatePlantEvent extends PlantEvent {
  UpdatePlantEvent(this.plant);
  final Plant plant;

  @override
  List<Object> get props => [plant];
}

class DeletePlantEvent extends PlantEvent {
  DeletePlantEvent(this.id);
  final String id;

  @override
  List<Object> get props => [id];
}
