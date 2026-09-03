import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('authRedirectLocation (decision matrix)', () {
    test('guarded locations redirect when logged out', () {
      for (final path in ['/', '/animals', '/revenue', '/lands', '/analytics/streak']) {
        expect(AppRouter.authRedirectLocation(loggedIn: false, location: path),
            AppRoutePath.googleLogin, reason: path);
      }
    });

    test('public locations never redirect', () {
      for (final path in [
        AppRoutePath.splash,
        AppRoutePath.googleLogin,
        AppRoutePath.onboarding,
      ]) {
        expect(
            AppRouter.authRedirectLocation(loggedIn: false, location: path), isNull,
            reason: path);
      }
    });

    test('logged-in users are never redirected', () {
      for (final path in ['/', '/settings', AppRoutePath.googleLogin]) {
        expect(AppRouter.authRedirectLocation(loggedIn: true, location: path),
            isNull, reason: path);
      }
    });
  });

  group('router integration', () {
    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

    setUp(() async {
      AppConfig.initialize();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // Without a handler the secure-storage channel's future never resolves
      // in tests, hanging the async redirect; null = "no stored value".
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
      await GetIt.instance.reset();
      await di.init();
    });

    tearDown(() => GetIt.instance.reset());

    testWidgets('unauthenticated deep navigation lands on the login page',
        (tester) async {
      final router = AppRouter().router;
      await tester.pumpWidget(
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      // Fire SplashPage's login-check timer while splash is mounted so no
      // timer is pending at teardown (its own removal is Phase 5, P3-08).
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      router.go('/lands'); // guarded route
      // The redirect is async (storage read); give its future explicit
      // event-loop turns before asserting.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (router.routerDelegate.currentConfiguration.uri.path ==
            AppRoutePath.googleLogin) {
          break;
        }
      }

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutePath.googleLogin,
        reason: 'guarded route must redirect an unauthenticated user to login',
      );

      // Drain the AnalyticsService 30 s flush timer that splash's
      // track('app_open') started (its test-DI stub is Phase 7, F1-08).
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
    });
  });
}
