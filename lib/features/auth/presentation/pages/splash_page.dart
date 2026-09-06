import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/offline/offline_flag_store.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/version/upgrade_dialog.dart';
import 'package:farm_tracker/core/version/version_check.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const splashMinDisplay = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    sl<AnalyticsService>().track('app_open');
    // Fire-and-forget: the version check runs concurrently and must NEVER
    // block, delay, or gate navigation (rule zero). It drives no routing - it
    // only shows an upgrade dialog ON TOP if the backend reports this client
    // is behind. It is deliberately not awaited here.
    unawaited(_checkAppVersion());
    // Check for existing login after a short delay
    Future.delayed(splashMinDisplay, () {
      if (!mounted) return;
      context.read<AuthBloc>().add(CheckExistingLoginEvent());
    });
  }

  /// Queries `GET /api/v1/meta` and, if this client is behind, shows the
  /// upgrade prompt on top of the current screen. Every failure mode - a
  /// timeout, a 5xx, a dropped connection, a malformed/garbage body, a missing
  /// field - is swallowed: no dialog, and launch proceeds untouched. Navigation
  /// is owned entirely by the BlocListener below and does not wait on this.
  Future<void> _checkAppVersion() async {
    try {
      final response = await sl<Dio>().get<dynamic>(
        '/api/v1/meta',
        options: Options(
          // A short, independent timeout so a hung network can never leave the
          // check pending; the connect/receive timeouts on the shared Dio also
          // apply. Either way this cannot block navigation.
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      await _applyOfflineFlag(response.data);
      final requirement = decideUpgrade(response.data, AppConfig.appVersion);
      if (requirement == UpgradeRequirement.none) return;
      // Guard the BuildContext across the network await. If the splash has
      // already navigated on, mounted is false and we simply skip - the next
      // launch re-checks. Launch is never blocked to keep this context alive.
      if (!mounted) return;
      await UpgradeDialog.show(
        context,
        forced: requirement == UpgradeRequirement.forced,
      );
    } catch (_) {
      // Swallow everything: a failed/slow/garbage /meta must be invisible.
    }
  }

  /// Reads the server-controlled `offline_enabled` kill-switch out of a
  /// successful `/meta` response and applies it: updates the runtime
  /// [OfflineConfig.enabled], persists it via [OfflineFlagStore] so it
  /// survives to the next launch, and — only when the flag just flipped from
  /// off to on — kicks an immediate [SyncEngine.syncNow] so a pending outbox
  /// (or a fresh pull) doesn't wait for the next launch/resume/connectivity
  /// trigger. A no-op when the parsed value matches the current flag. Callers
  /// only reach this after a successful GET, so a `/meta` failure leaves the
  /// flag at its persisted/default value untouched (fail to last-known).
  Future<void> _applyOfflineFlag(dynamic metaData) async {
    final parsed = parseOfflineEnabled(metaData);
    final decision = decideOfflineFlagChange(
      parsedValue: parsed,
      currentValue: OfflineConfig.enabled,
    );
    if (!decision.changed) return;
    OfflineConfig.enabled = parsed;
    await const OfflineFlagStore().write(parsed);
    if (decision.newlyEnabled) {
      unawaited(sl<SyncEngine>().syncNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // User is logged in, navigate to landing page
          context.go(AppRoutePath.home);
        } else if (state is AuthInitial) {
          // User is not logged in, navigate to google login page
          context.go(AppRoutePath.googleLogin);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon or logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.agriculture,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 30),
              // App name
              Text(
                'Shamba+',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Managing your farm, simplified',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onPrimary.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Checking login status...',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimary.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The outcome of comparing a freshly parsed `offline_enabled` value against
/// the flag's current runtime value.
///
/// A pure decision, deliberately factored out of [_SplashPageState] so it's
/// testable without pumping a widget: [changed] is `false` when the parsed
/// value already matches [OfflineConfig.enabled] (nothing to persist or
/// apply); when `true`, [newlyEnabled] says whether this is specifically an
/// off-to-on transition, the only case that should kick an immediate sync.
class OfflineFlagDecision {
  const OfflineFlagDecision({required this.changed, required this.newlyEnabled});

  final bool changed;
  final bool newlyEnabled;
}

/// Decides what to do with a parsed `offline_enabled` value ([parsedValue])
/// given the flag's [currentValue]. See [OfflineFlagDecision].
OfflineFlagDecision decideOfflineFlagChange({
  required bool parsedValue,
  required bool currentValue,
}) {
  if (parsedValue == currentValue) {
    return const OfflineFlagDecision(changed: false, newlyEnabled: false);
  }
  return OfflineFlagDecision(changed: true, newlyEnabled: parsedValue);
}
