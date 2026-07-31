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
    required this.fiscalYearStartMonth,
    this.farmName,
    this.location,
  });
  final String firstName;
  final String lastName;
  final int fiscalYearStartMonth;
  final String? farmName;
  final String? location;

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    fiscalYearStartMonth,
    farmName,
    location,
  ];
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
