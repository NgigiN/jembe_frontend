import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded({required this.user});
  final User user;

  @override
  List<Object?> get props => [user];
}

class ProfileOperationSuccess extends ProfileState {
  const ProfileOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class ProfileError extends ProfileState {
  const ProfileError({required this.message});
  final String message;

  @override
  List<Object?> get props => [message];
}
