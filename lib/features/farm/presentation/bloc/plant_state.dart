import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';

abstract class PlantState extends Equatable {
  const PlantState({this.plants = const []});
  final List<Plant> plants;

  @override
  List<Object> get props => [plants];
}

class PlantInitial extends PlantState {}

class PlantLoading extends PlantState {
  const PlantLoading({super.plants});
}

class PlantLoaded extends PlantState {
  const PlantLoaded({required super.plants});

  @override
  List<Object> get props => [plants];
}

class PlantError extends PlantState {
  const PlantError(this.message, {super.plants});
  final String message;

  @override
  List<Object> get props => [message, plants];
}
