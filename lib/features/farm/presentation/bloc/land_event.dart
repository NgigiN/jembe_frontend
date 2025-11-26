import 'package:equatable/equatable.dart';
import '../../domain/entities/land.dart';

abstract class LandEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetLandsEvent extends LandEvent {}

class AddLandEvent extends LandEvent {
  final Land land;

  AddLandEvent(this.land);

  @override
  List<Object> get props => [land];
}

class UpdateLandEvent extends LandEvent {
  final Land land;

  UpdateLandEvent(this.land);

  @override
  List<Object> get props => [land];
}

class DeleteLandEvent extends LandEvent {
  final String id;

  DeleteLandEvent(this.id);

  @override
  List<Object> get props => [id];
}
