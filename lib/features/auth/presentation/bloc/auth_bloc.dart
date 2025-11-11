import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
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
      appLogger.logAuthEvent('Login attempt', details: {'email': event.email});

      try {
        final result = await login(
          LoginParams(email: event.email, password: event.password),
        );
        await result.fold(
          (failure) async {
            String message = 'Login failed';
            if (failure is ServerFailure && failure.errorMessage != null) {
              message = failure.errorMessage!;
            }
            appLogger.logAuthEvent(
              'Login failed',
              details: {'email': event.email, 'error': message},
            );
            emit(AuthError(message));
          },
          (user) async {
            appLogger.logAuthEvent(
              'Login successful',
              userId: user.id,
              details: {'email': event.email, 'name': user.name},
            );
            emit(AuthAuthenticated(user));
          },
        );
      } catch (e) {
        appLogger.logError('LoginEvent', e);
        emit(AuthError('Login failed: ${e.toString()}'));
      }
    });

    on<SignupEvent>((event, emit) async {
      emit(AuthLoading());
      try {
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
            // Emit success and let the UI handle the navigation
            emit(SignupSuccess());
          },
        );
      } catch (e) {
        emit(AuthError('Signup failed: ${e.toString()}'));
      }
    });

    on<ResetAuthState>((event, emit) {
      emit(AuthInitial());
    });

    on<LogoutEvent>((event, emit) async {
      appLogger.logAuthEvent('Logout');
      await UserStorageService.clearUserData();
      emit(AuthInitial());
    });

    on<CheckExistingLoginEvent>((event, emit) async {
      emit(AuthLoading());
      appLogger.info(LogCategory.auth, 'Checking existing login');

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
          appLogger.logAuthEvent(
            'Existing login found',
            userId: user.id,
            details: {'email': user.email},
          );
          emit(AuthAuthenticated(user));
        } else {
          appLogger.warning(
            LogCategory.auth,
            'User data not found despite being logged in',
          );
          emit(AuthInitial());
        }
      } else {
        appLogger.info(LogCategory.auth, 'No existing login found');
        emit(AuthInitial());
      }
    });
  }
}
