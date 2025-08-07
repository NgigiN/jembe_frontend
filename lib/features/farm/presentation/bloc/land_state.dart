import 'package:equatable/equatable.dart';
import '../../domain/entities/land.dart';

abstract class LandState extends Equatable {
  final List<Land> lands;

  const LandState({this.lands = const []});

  @override
  List<Object> get props => [lands];
}

class LandInitial extends LandState {}

class LandLoading extends LandState {
  const LandLoading({super.lands});
}

class LandLoaded extends LandState {
  const LandLoaded({required super.lands});

  @override
  List<Object> get props => [lands];
}

class LandError extends LandState {
  final String message;

  const LandError(this.message, {super.lands});

  @override
  List<Object> get props => [message, lands];
}
