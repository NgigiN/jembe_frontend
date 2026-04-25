import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';

abstract class LandState extends Equatable {
  const LandState({this.lands = const []});
  final List<Land> lands;

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
  const LandError(this.message, {super.lands});
  final String message;

  @override
  List<Object> get props => [message, lands];
}
