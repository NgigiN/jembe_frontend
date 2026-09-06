import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';

abstract class HarvestEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetHarvestsEvent extends HarvestEvent {
  GetHarvestsEvent({this.seasonId});
  final String? seasonId;

  @override
  List<Object> get props => [seasonId ?? ''];
}

/// Flag-ON only: subscribes (or re-subscribes) `HarvestBloc` to
/// `repository.watchHarvests(seasonId:)`, scoped exactly like the existing
/// `GetHarvestsEvent(seasonId:)`. Every subsequent stream emission is turned
/// into a `HarvestLoaded(harvests: ...)` state — see `HarvestBloc`'s
/// internal `_HarvestsUpdated` event for how.
class WatchHarvestsEvent extends HarvestEvent {
  WatchHarvestsEvent({this.seasonId});
  final String? seasonId;

  @override
  List<Object> get props => [seasonId ?? ''];
}

class AddHarvestEvent extends HarvestEvent {
  AddHarvestEvent(this.harvest);
  final Harvest harvest;

  @override
  List<Object> get props => [harvest];
}

class UpdateHarvestEvent extends HarvestEvent {
  UpdateHarvestEvent(this.harvest);
  final Harvest harvest;

  @override
  List<Object> get props => [harvest];
}

class DeleteHarvestEvent extends HarvestEvent {
  DeleteHarvestEvent(this.id);
  final String id;

  @override
  List<Object> get props => [id];
}