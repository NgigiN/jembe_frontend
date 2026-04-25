import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';

abstract class HerdState extends Equatable {
  const HerdState({this.herds = const []});
  final List<Herd> herds;

  @override
  List<Object?> get props => [herds];
}

class HerdInitial extends HerdState {}

class HerdLoading extends HerdState {
  const HerdLoading({super.herds});
}

class HerdLoaded extends HerdState {
  const HerdLoaded(List<Herd> herds) : super(herds: herds);

  @override
  List<Object?> get props => [herds];
}

class HerdError extends HerdState {

  const HerdError(this.message, {super.herds});
  final String message;

  @override
  List<Object?> get props => [message, herds];
}

