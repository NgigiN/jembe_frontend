import 'package:equatable/equatable.dart';
import '../../domain/entities/herd.dart';

abstract class HerdState extends Equatable {
  final List<Herd> herds;
  const HerdState({this.herds = const []});

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
  final String message;

  const HerdError(this.message, {super.herds});

  @override
  List<Object?> get props => [message, herds];
}

