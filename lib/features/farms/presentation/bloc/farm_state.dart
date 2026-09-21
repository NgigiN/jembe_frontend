import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

abstract class FarmState extends Equatable {
  const FarmState();
  @override
  List<Object?> get props => [];
}

class FarmInitial extends FarmState {}

class FarmLoaded extends FarmState {
  const FarmLoaded({
    required this.farms,
    required this.currentFarmId,
    required this.currentRole,
  });

  final List<Farm> farms;
  final int? currentFarmId;
  final FarmRole? currentRole;

  @override
  List<Object?> get props => [farms, currentFarmId, currentRole];
}

class FarmError extends FarmState {
  const FarmError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
