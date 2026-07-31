import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';

abstract class SeasonState extends Equatable {
  const SeasonState({this.seasons = const []});
  final List<Season> seasons;

  @override
  List<Object?> get props => [seasons];
}

class SeasonInitial extends SeasonState {}

class SeasonLoading extends SeasonState {
  const SeasonLoading({super.seasons});
}

class SeasonLoaded extends SeasonState {
  const SeasonLoaded({required super.seasons, this.successMessage});
  final String? successMessage;

  @override
  List<Object?> get props => [seasons, successMessage];
}

class SeasonError extends SeasonState {
  const SeasonError(this.message, {super.seasons});
  final String message;

  @override
  List<Object> get props => [message, seasons];
}
