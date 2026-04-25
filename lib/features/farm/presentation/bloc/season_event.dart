import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';

abstract class SeasonEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetSeasonsEvent extends SeasonEvent {}

class AddSeasonEvent extends SeasonEvent {
  AddSeasonEvent(this.season);
  final Season season;

  @override
  List<Object> get props => [season];
}

class UpdateSeasonEvent extends SeasonEvent {
  UpdateSeasonEvent(this.season);
  final Season season;

  @override
  List<Object> get props => [season];
}

class DeleteSeasonEvent extends SeasonEvent {
  DeleteSeasonEvent(this.id);
  final String id;

  @override
  List<Object> get props => [id];
}
