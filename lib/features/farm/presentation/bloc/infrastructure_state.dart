import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';

abstract class InfrastructureState extends Equatable {
  const InfrastructureState({this.infrastructures = const []});
  final List<Infrastructure> infrastructures;

  @override
  List<Object?> get props => [infrastructures];
}

class InfrastructureInitial extends InfrastructureState {}

class InfrastructureLoading extends InfrastructureState {
  const InfrastructureLoading({super.infrastructures});
}

class InfrastructureLoaded extends InfrastructureState {
  const InfrastructureLoaded(List<Infrastructure> infrastructures)
      : super(infrastructures: infrastructures);

  @override
  List<Object?> get props => [infrastructures];
}

class InfrastructureError extends InfrastructureState {
  const InfrastructureError(this.message, {super.infrastructures});
  final String message;

  @override
  List<Object?> get props => [message, infrastructures];
}
