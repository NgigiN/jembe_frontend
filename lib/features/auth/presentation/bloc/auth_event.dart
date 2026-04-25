import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GoogleSignInRequested extends AuthEvent {
  GoogleSignInRequested();
}

class ResetAuthState extends AuthEvent {}

class LogoutEvent extends AuthEvent {}

class CheckExistingLoginEvent extends AuthEvent {}
