import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';

abstract class AuthState extends Equatable {
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  AuthAuthenticated(this.user);
  final User user;

  @override
  List<Object> get props => [user];
}

class AuthError extends AuthState {
  AuthError(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}
