import 'package:equatable/equatable.dart';
import '../../domain/entities/season.dart';

abstract class SeasonEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetSeasonsEvent extends SeasonEvent {}

class AddSeasonEvent extends SeasonEvent {
  final Season season;

  AddSeasonEvent(this.season);

  @override
  List<Object> get props => [season];
}
