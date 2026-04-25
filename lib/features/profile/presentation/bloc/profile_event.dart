import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class FetchProfileEvent extends ProfileEvent {}

class UpdateProfileEvent extends ProfileEvent {
  const UpdateProfileEvent({
    required this.firstName,
    required this.lastName,
    this.farmName,
    this.location,
  });
  final String firstName;
  final String lastName;
  final String? farmName;
  final String? location;

  @override
  List<Object?> get props => [firstName, lastName, farmName, location];
}

class ChangePasswordEvent extends ProfileEvent {
  const ChangePasswordEvent({
    required this.oldPassword,
    required this.newPassword,
  });
  final String oldPassword;
  final String newPassword;

  @override
  List<Object?> get props => [oldPassword, newPassword];
}
