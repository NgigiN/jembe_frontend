import 'package:equatable/equatable.dart';
import '../../domain/entities/animal_type.dart';

abstract class AnimalTypeState extends Equatable {
  const AnimalTypeState();

  @override
  List<Object?> get props => [];
}

class AnimalTypeInitial extends AnimalTypeState {}

class AnimalTypeLoading extends AnimalTypeState {}

class AnimalTypeLoaded extends AnimalTypeState {
  final List<AnimalType> animalTypes;

  const AnimalTypeLoaded(this.animalTypes);

  @override
  List<Object?> get props => [animalTypes];
}

class AnimalTypeError extends AnimalTypeState {
  final String message;

  const AnimalTypeError(this.message);

  @override
  List<Object?> get props => [message];
}

