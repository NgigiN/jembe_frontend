import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';

abstract class LandEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetLandsEvent extends LandEvent {}

class AddLandEvent extends LandEvent {
  AddLandEvent(this.land);
  final Land land;

  @override
  List<Object> get props => [land];
}

class UpdateLandEvent extends LandEvent {
  UpdateLandEvent(this.land);
  final Land land;

  @override
  List<Object> get props => [land];
}

class DeleteLandEvent extends LandEvent {
  DeleteLandEvent(this.id);
  final String id;

  @override
  List<Object> get props => [id];
}
