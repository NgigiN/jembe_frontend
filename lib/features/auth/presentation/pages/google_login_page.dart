import 'dart:async';

import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/farms/data/services/farm_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Where a freshly authenticated user belongs.
///
/// Onboarding is the "you have no farm" path. This used to be decided from the
/// user's own `farmName`/`location` fields, which are empty for every new
/// account — but since V2 tenancy the backend creates a default farm during
/// sign-in, so a new user was shown a form asking them to set up a farm they
/// already had, and completing it would have made a second one.
String postSignInLocation({required bool hasFarm}) =>
    hasFarm ? AppRoutePath.home : AppRoutePath.onboarding;

class GoogleLoginPage extends StatelessWidget {
  const GoogleLoginPage({super.key});

  /// Reads the farms the sign-in response already persisted, then routes.
  ///
  /// `FarmStorageService.saveFarms` runs inside the sign-in call itself, so by
  /// the time this state arrives the list is on disk and no extra request is
  /// needed.
  Future<void> _goAfterSignIn(BuildContext context) async {
    final farms = await FarmStorageService.getFarms();
    if (!context.mounted) return;
    context.go(postSignInLocation(hasFarm: farms.isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          // AuthCancelled is a subclass of AuthInitial, so it is checked first.
          if (state is AuthCancelled) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  duration: const Duration(seconds: 6),
                ),
              );
          } else if (state is AuthAuthenticated) {
            unawaited(_goAfterSignIn(context));
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.agriculture,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to Shamba+',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'A minimal farm tracking app for smart Kenyan farmers.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 64),
                  if (state is AuthLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        context.read<AuthBloc>().add(GoogleSignInRequested());
                      },
                      icon: const Icon(Icons.login),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
