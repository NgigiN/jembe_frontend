import 'package:equatable/equatable.dart';
import '../../domain/entities/land.dart';
import '../../domain/entities/plant.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/input.dart';
import '../../domain/entities/animal.dart';

abstract class FarmState extends Equatable {
  final List<Land> lands;
  final List<Plant> plants;
  final List<Season> seasons;
  final List<Activity> activities;
  final List<Input> inputs;
  final List<Animal> animals;

  const FarmState({
    this.lands = const [],
    this.plants = const [],
    this.seasons = const [],
    this.activities = const [],
    this.inputs = const [],
    this.animals = const [],
  });

  @override
  List<Object> get props => [lands, plants, seasons, activities, inputs, animals];
}

class FarmInitial extends FarmState {}

class FarmLoading extends FarmState {
  const FarmLoading({
    super.lands,
    super.plants,
    super.seasons,
    super.activities,
    super.inputs,
    super.animals,
  });
}

class FarmLoaded extends FarmState {
  const FarmLoaded({
    super.lands,
    super.plants,
    super.seasons,
    super.activities,
    super.inputs,
    super.animals,
  });
}

class FarmError extends FarmState {
  final String message;

  const FarmError(
    this.message, {
    super.lands,
    super.plants,
    super.seasons,
    super.activities,
    super.inputs,
    super.animals,
  });

  @override
  List<Object> get props => [
    message,
    lands,
    plants,
    seasons,
    activities,
    inputs,
    animals,
  ];
}
