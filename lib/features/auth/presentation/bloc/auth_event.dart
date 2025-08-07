import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class SignupEvent extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String farmName;
  final String location;
  SignupEvent({
    required this.email,
    required this.password,
    required this.name,
    required this.farmName,
    required this.location,
  });

  @override
  List<Object> get props => [email, password, name, farmName, location];
}

class ResetAuthState extends AuthEvent {}

class LogoutEvent extends AuthEvent {}

class CheckExistingLoginEvent extends AuthEvent {}
