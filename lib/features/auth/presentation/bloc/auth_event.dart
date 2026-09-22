import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GoogleSignInRequested extends AuthEvent {
  GoogleSignInRequested();
}

class GoogleSignInWebAccountReceived extends AuthEvent {
  GoogleSignInWebAccountReceived(this.idToken);
  final String idToken;

  @override
  List<Object> get props => [idToken];
}

class ResetAuthState extends AuthEvent {}

class LogoutEvent extends AuthEvent {}

class CheckExistingLoginEvent extends AuthEvent {}
