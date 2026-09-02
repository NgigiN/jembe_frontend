import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

abstract class AnimalState extends Equatable {
  const AnimalState({this.animals = const []});
  final List<Animal> animals;

  @override
  List<Object?> get props => [animals];
}

class AnimalInitial extends AnimalState {}

class AnimalLoading extends AnimalState {
  const AnimalLoading({super.animals});
}

class AnimalLoaded extends AnimalState {
  const AnimalLoaded({required super.animals, this.successMessage});
  final String? successMessage;

  @override
  List<Object?> get props => [animals, successMessage];
}

class AnimalError extends AnimalState {
  const AnimalError(this.message, {super.animals});
  final String message;

  @override
  List<Object> get props => [message, animals];
}
