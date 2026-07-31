import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart' as auth_google;
import 'package:farm_tracker/features/auth/domain/usecases/google_sign_in_usecase.dart';
import 'package:farm_tracker/features/auth/data/services/google_sign_in_service.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';

import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this.googleSignInUseCase}) : super(AuthInitial()) {
    on<GoogleSignInRequested>((event, emit) async {
      emit(AuthLoading());
      appLogger.logAuthEvent('Google Sign-In attempt');

      if (!_supportsGoogleSignIn) {
        const message =
            'Google Sign-In is only available on Android. '
            'Connect a phone or emulator, then run ./run_local.sh.';
        appLogger.warning(LogCategory.auth, message);
        emit(AuthError(message));
        return;
      }

      try {
        await GoogleSignInService.ensureInitialized();

        final auth_google.GoogleSignIn googleSignIn = auth_google.GoogleSignIn.instance;

        final auth_google.GoogleSignInAccount? account = await googleSignIn.authenticate();

        if (account == null) {
          appLogger.logAuthEvent('Google Sign-In cancelled by user');
          emit(AuthError('Sign-in cancelled'));
          return;
        }

        final auth_google.GoogleSignInAuthentication auth = await account.authentication;
        final String? idToken = auth.idToken;

        if (idToken == null) {
          emit(AuthError('Failed to retrieve ID Token from Google'));
          return;
        }

        final result = await googleSignInUseCase(idToken);
        
        await result.fold(
          (failure) async {
            final message = resolveFailureMessage(failure, 'Google Sign-In failed');
            appLogger.logAuthEvent(
              'Google Sign-In failed',
              details: {'error': message},
            );
            emit(AuthError(message));
          },
          (user) async {
            appLogger.logAuthEvent(
              'Google Sign-In successful',
              userId: user.id,
              details: {'email': user.email, 'name': user.fullName},
            );
            emit(AuthAuthenticated(user));
          },
        );
      } catch (e) {
        appLogger.logError('GoogleSignInRequested', e);
        emit(AuthError('Google Sign-In failed. Please try again.'));
      }
    });

    on<ResetAuthState>((event, emit) {
      emit(AuthInitial());
    });

    on<LogoutEvent>((event, emit) async {
      appLogger.logAuthEvent('Logout');
      await UserStorageService.clearUserData();
      final auth_google.GoogleSignIn googleSignIn = auth_google.GoogleSignIn.instance;
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      emit(AuthInitial());
    });

    on<CheckExistingLoginEvent>((event, emit) async {
      emit(AuthLoading());
      appLogger.info(LogCategory.auth, 'Checking existing login');

      final isLoggedIn = await UserStorageService.isLoggedIn();
      if (isLoggedIn) {
        final userData = await UserStorageService.getUserData();
        if (userData != null) {
          final nameParts = userData.name.split(' ');
          final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
          final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          final user = User(
            id: userData.id,
            email: userData.email,
            firstName: firstName,
            lastName: lastName,
            farmName: userData.farmName,
            location: userData.location,
            pictureUrl: userData.pictureUrl,
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
  final GoogleSignInUseCase googleSignInUseCase;

  static bool get _supportsGoogleSignIn =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
