import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';

abstract class AnimalTypeState extends Equatable {
  const AnimalTypeState({this.animalTypes = const []});
  final List<AnimalType> animalTypes;

  @override
  List<Object?> get props => [animalTypes];
}

class AnimalTypeInitial extends AnimalTypeState {}

class AnimalTypeLoading extends AnimalTypeState {
  const AnimalTypeLoading({super.animalTypes});
}

class AnimalTypeLoaded extends AnimalTypeState {
  const AnimalTypeLoaded(List<AnimalType> animalTypes) : super(animalTypes: animalTypes);

  @override
  List<Object?> get props => [animalTypes];
}

class AnimalTypeError extends AnimalTypeState {

  const AnimalTypeError(this.message, {super.animalTypes});
  final String message;

  @override
  List<Object?> get props => [message, animalTypes];
}

