import 'package:equatable/equatable.dart';

abstract class HerdActivityState extends Equatable {
  const HerdActivityState();

  @override
  List<Object?> get props => [];
}

class HerdActivityInitial extends HerdActivityState {}

class HerdActivityLoading extends HerdActivityState {}

class HerdActivitySuccess extends HerdActivityState {
  const HerdActivitySuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class HerdActivityError extends HerdActivityState {
  const HerdActivityError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
