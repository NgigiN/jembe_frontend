// lib/features/web_console/presentation/pages/web_sign_in_page.dart
import 'dart:async';

import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/features/auth/data/services/google_sign_in_service.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart' as auth_google;

/// Sign-in (DESIGN_SPEC §4, screen 01): a deep-green brand panel beside a
/// single 380px column that does one thing.
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
        child: SignInView(ready: _ready, failed: _error),
      ),
    );
  }
}

/// The sign-in screen's drawing, with no bloc in sight.
class SignInView extends StatelessWidget {
  const SignInView({
    required this.ready,
    this.failed = false,
    this.signInButton = const GoogleSignInButton(),
    super.key,
  });

  final bool ready;
  final bool failed;

  /// The real Google button renders through a platform view, so a preview
  /// or a test swaps in something it can draw.
  final Widget signInButton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < ConsoleMetrics.shellBreakpoint;
        final column = _SignInColumn(
          ready: ready,
          failed: failed,
          showBrand: narrow,
          signInButton: signInButton,
        );
        // The brand panel is the first thing to go on a narrow window: it
        // is the half of this screen that carries no controls.
        if (narrow) return column;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 11, child: _BrandPanel()),
            Expanded(flex: 10, child: column),
          ],
        );
      },
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: context.console.deep,
      child: Stack(
        children: [
          // Two soft circles, barely there — enough to keep a large flat
          // green field from reading as a rendering error.
          Positioned(
            left: -90,
            top: -60,
            child: _Glow(color: scheme.primary, size: 320),
          ),
          Positioned(
            right: -120,
            bottom: -80,
            child: _Glow(color: scheme.primaryContainer, size: 380),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.eco, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Shamba+',
                      style: AppTypography.wordmark.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    style: AppTypography.signInHeadline.copyWith(
                      color: Colors.white,
                    ),
                    children: [
                      const TextSpan(text: 'Every shilling on the farm, '),
                      TextSpan(
                        text: 'accounted for.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: scheme.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Read back everything your team logged in the field — '
                  'costs, harvests and sales, farm by farm.',
                  style: AppTypography.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.6,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SignInColumn extends StatelessWidget {
  const _SignInColumn({
    required this.ready,
    required this.failed,
    required this.showBrand,
    required this.signInButton,
  });

  final bool ready;
  final bool failed;
  final Widget signInButton;

  /// On a narrow window the brand panel is gone, so the wordmark moves
  /// here — otherwise the page would not say what it is.
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBrand) ...[
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.eco,
                        size: 18,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text.rich(
                      TextSpan(
                        style: AppTypography.wordmark.copyWith(
                          color: scheme.onSurface,
                        ),
                        children: [
                          const TextSpan(text: 'Shamba'),
                          TextSpan(
                            text: '+',
                            style: TextStyle(color: scheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
              const Text('Sign in', style: AppTypography.pageTitleLarge),
              const SizedBox(height: 8),
              Text(
                'Use the Google account you signed up with on the phone. '
                'The console shows the same farms.',
                style: AppTypography.bodyDense.copyWith(
                  color: console.muted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              if (failed)
                _Notice(
                  icon: Icons.cloud_off,
                  color: scheme.error,
                  background: console.negativeContainer,
                  text: 'Sign-in is unavailable just now. Refresh the page and '
                      'try again.',
                )
              else if (ready)
                Align(alignment: Alignment.centerLeft, child: signInButton)
              else
                const _ButtonPlaceholder(),
              const SizedBox(height: 22),
              ConsoleCard(
                color: console.surfaceLow,
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.phone_android,
                      size: 20,
                      color: console.onSurface2,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'New here? Start on the Android app — it creates your '
                        'farm and works without signal. The console is for '
                        'reading it back.',
                        style: AppTypography.bodyDense.copyWith(
                          color: console.onSurface2,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'By signing in you agree to the terms and privacy policy.',
                style: AppTypography.meta.copyWith(color: console.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonPlaceholder extends StatelessWidget {
  const _ButtonPlaceholder();

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
        border: Border.all(color: console.outline),
      ),
      child: Text(
        'Preparing sign-in\u2026',
        style: AppTypography.bodyDense.copyWith(color: console.muted),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyDense.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
