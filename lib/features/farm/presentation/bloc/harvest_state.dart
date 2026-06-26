import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';

abstract class HarvestState extends Equatable {
  const HarvestState({this.harvests = const []});
  final List<Harvest> harvests;

  @override
  List<Object> get props => [harvests];
}

class HarvestInitial extends HarvestState {}

class HarvestLoading extends HarvestState {
  const HarvestLoading({super.harvests});
}

class HarvestLoaded extends HarvestState {
  const HarvestLoaded({required super.harvests});

  @override
  List<Object> get props => [harvests];
}

class HarvestError extends HarvestState {
  const HarvestError(this.message, {super.harvests});
  final String message;

  @override
  List<Object> get props => [message, harvests];
}