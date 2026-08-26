import 'package:equatable/equatable.dart';

abstract class InfrastructureEvent extends Equatable {
  const InfrastructureEvent();

  @override
  List<Object?> get props => [];
}

class GetInfrastructuresEvent extends InfrastructureEvent {}

class AddInfrastructureEvent extends InfrastructureEvent {
  const AddInfrastructureEvent({
    required this.type,
    required this.name,
    required this.location,
    required this.cost,
    required this.date,
    required this.userId,
    this.notes,
  });

  final String type;
  final String name;
  final String location;
  final double cost;
  final DateTime date;
  final String userId;
  final String? notes;

  @override
  List<Object?> get props => [type, name, location, cost, date, userId, notes];
}

class UpdateInfrastructureEvent extends InfrastructureEvent {
  const UpdateInfrastructureEvent({
    required this.id,
    required this.type,
    required this.name,
    required this.location,
    required this.cost,
    required this.date,
    this.notes,
  });

  final String id;
  final String type;
  final String name;
  final String location;
  final double cost;
  final DateTime date;
  final String? notes;

  @override
  List<Object?> get props => [id, type, name, location, cost, date, notes];
}

class DeleteInfrastructureEvent extends InfrastructureEvent {
  const DeleteInfrastructureEvent(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
