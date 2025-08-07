import 'package:equatable/equatable.dart';
import '../../domain/entities/season.dart';

abstract class SeasonState extends Equatable {
  final List<Season> seasons;

  const SeasonState({this.seasons = const []});

  @override
  List<Object> get props => [seasons];
}

class SeasonInitial extends SeasonState {}

class SeasonLoading extends SeasonState {
  const SeasonLoading({super.seasons});
}

class SeasonLoaded extends SeasonState {
  const SeasonLoaded({required super.seasons});

  @override
  List<Object> get props => [seasons];
}

class SeasonError extends SeasonState {
  final String message;

  const SeasonError(this.message, {super.seasons});

  @override
  List<Object> get props => [message, seasons];
}
