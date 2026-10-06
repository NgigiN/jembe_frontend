import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';

abstract class AuthState extends Equatable {
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

/// Sign-in ended without completing because the Google sheet was dismissed.
///
/// Deliberately a subclass of [AuthInitial] rather than a sibling: the splash
/// and landing pages both gate on `state is AuthInitial`, and a sibling state
/// would silently change navigation on those screens as a side effect of this
/// fix. All this adds is a message for the UI to show.
///
/// It exists because a dismissed sheet used to emit a bare [AuthInitial] and
/// display nothing at all. The sign-in screen simply reappeared, so tapping
/// again re-opened the account chooser — an unexplained loop that produced no
/// server traffic and no message anywhere.
class AuthCancelled extends AuthInitial {
  AuthCancelled(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

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
