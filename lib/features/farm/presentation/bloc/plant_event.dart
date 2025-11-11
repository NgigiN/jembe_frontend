import 'package:equatable/equatable.dart';
import '../../domain/entities/plant.dart';

abstract class PlantEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetPlantsEvent extends PlantEvent {}

class AddPlantEvent extends PlantEvent {
  final Plant plant;

  AddPlantEvent(this.plant);

  @override
  List<Object> get props => [plant];
}
