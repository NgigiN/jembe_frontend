import 'package:equatable/equatable.dart';
import '../../domain/entities/herd.dart';

abstract class HerdState extends Equatable {
  const HerdState();

  @override
  List<Object?> get props => [];
}

class HerdInitial extends HerdState {}

class HerdLoading extends HerdState {}

class HerdLoaded extends HerdState {
  final List<Herd> herds;

  const HerdLoaded(this.herds);

  @override
  List<Object?> get props => [herds];
}

class HerdError extends HerdState {
  final String message;

  const HerdError(this.message);

  @override
  List<Object?> get props => [message];
}

