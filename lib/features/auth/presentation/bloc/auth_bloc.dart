import 'package:farm_tracker/core/error/failures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/signup.dart';
import '../../data/services/user_storage_service.dart';
import '../../domain/entities/user.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final Login login;
  final Signup signup;

  AuthBloc({required this.login, required this.signup}) : super(AuthInitial()) {
    on<LoginEvent>((event, emit) async {
      emit(AuthLoading());
      final result = await login(
        LoginParams(email: event.email, password: event.password),
      );
      await result.fold((failure) async => emit(AuthError('Login failed')), (
        user,
      ) async {
        emit(AuthAuthenticated(user));
      });
    });

    on<SignupEvent>((event, emit) async {
      emit(AuthLoading());
      final result = await signup(
        SignupParams(
          email: event.email,
          password: event.password,
          name: event.name,
          farmName: event.farmName,
          location: event.location,
        ),
      );
      await result.fold(
        (failure) async {
          // Try to extract a message from the failure if possible
          String message = 'Signup failed';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(AuthError(message));
        },
        (user) async {
          emit(SignupSuccess());
          // Reset state after a short delay to clear any lingering states
          await Future.delayed(const Duration(milliseconds: 100));
          emit(AuthInitial());
        },
      );
    });

    on<ResetAuthState>((event, emit) {
      emit(AuthInitial());
    });

    on<LogoutEvent>((event, emit) async {
      await UserStorageService.clearUserData();
      emit(AuthInitial());
    });

    on<CheckExistingLoginEvent>((event, emit) async {
      emit(AuthLoading());
      final isLoggedIn = await UserStorageService.isLoggedIn();
      if (isLoggedIn) {
        final userData = await UserStorageService.getUserData();
        if (userData != null) {
          final user = User(
            id: userData.id,
            email: userData.email,
            name: userData.name,
            farmName: userData.farmName,
            location: userData.location,
          );
          emit(AuthAuthenticated(user));
        } else {
          emit(AuthInitial());
        }
      } else {
        emit(AuthInitial());
      }
    });
  }
}
