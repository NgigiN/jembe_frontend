import 'package:equatable/equatable.dart';
import '../../domain/entities/plant.dart';

abstract class PlantState extends Equatable {
  final List<Plant> plants;

  const PlantState({this.plants = const []});

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
  final String message;

  const PlantError(this.message, {super.plants});

  @override
  List<Object> get props => [message, plants];
}
