// lib/features/web_console/presentation/pages/web_sign_in_page.dart
import 'dart:async';

import 'package:farm_tracker/features/auth/data/services/google_sign_in_service.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart' as auth_google;

class WebSignInPage extends StatefulWidget {
  const WebSignInPage({super.key, this.ensureInitialized, this.idTokenEvents});

  /// Injectable for tests; defaults to [GoogleSignInService.ensureInitialized]
  /// in production.
  final Future<void> Function()? ensureInitialized;

  /// Injectable for tests; defaults to a stream derived from
  /// `GoogleSignIn.instance.authenticationEvents` in production. Carries
  /// already-extracted ID tokens rather than the raw platform event type,
  /// since `GoogleSignInAccount` has a private constructor and cannot be
  /// fabricated in test code.
  final Stream<String>? idTokenEvents;

  @override
  State<WebSignInPage> createState() => _WebSignInPageState();
}

class _WebSignInPageState extends State<WebSignInPage> {
  bool _ready = false;
  bool _error = false;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await (widget.ensureInitialized ?? GoogleSignInService.ensureInitialized)();
      _subscription = (widget.idTokenEvents ?? _defaultIdTokenEvents()).listen(
        _onIdToken,
      );
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  // Stream (unlike Iterable) has no whereType method in dart:async, so the
  // sign-in-event filter + null-idToken filter are done with expand instead.
  Stream<String> _defaultIdTokenEvents() {
    return auth_google.GoogleSignIn.instance.authenticationEvents.expand((
      event,
    ) {
      if (event is auth_google.GoogleSignInAuthenticationEventSignIn) {
        final idToken = event.user.authentication.idToken;
        if (idToken != null) return [idToken];
      }
      return const <String>[];
    });
  }

  void _onIdToken(String idToken) {
    context.read<AuthBloc>().add(GoogleSignInWebAccountReceived(idToken));
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        child: Center(
          child: _error
              ? const Text(
                  'Sign-in is currently unavailable. Please try again shortly.',
                )
              : _ready
              ? const GoogleSignInButton()
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
