import 'package:equatable/equatable.dart';
import '../../domain/entities/animal_type.dart';

abstract class AnimalTypeState extends Equatable {
  final List<AnimalType> animalTypes;
  const AnimalTypeState({this.animalTypes = const []});

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
  final String message;

  const AnimalTypeError(this.message, {super.animalTypes});

  @override
  List<Object?> get props => [message, animalTypes];
}

