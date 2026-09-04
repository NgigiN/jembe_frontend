import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/auth/presentation/pages/splash_page.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(CheckExistingLoginEvent()));

  // SplashPage.initState reads AnalyticsService from the service locator
  // before the login-check delay, so it must be registered for the page
  // to build at all.
  setUp(() {
    sl.registerLazySingleton<AnalyticsService>(
      () => AnalyticsService(dio: MockDio()),
    );
  });

  tearDown(() {
    sl.unregister<AnalyticsService>();
  });

  testWidgets('dispatches CheckExistingLoginEvent within 300ms', (tester) async {
    final authBloc = MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: AuthInitial());
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(value: authBloc, child: const SplashPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    verify(() => authBloc.add(any(that: isA<CheckExistingLoginEvent>()))).called(1);

    // SplashPage.initState() calls AnalyticsService.track(), which schedules
    // a real 30s flush Timer. flutter_test's AutomatedTestWidgetsFlutterBinding
    // asserts no Timer is left pending when a test ends, so drain it
    // explicitly here rather than waiting. flush() cancels its own timer
    // first, then (since the buffer isn't empty) attempts a POST via the
    // unstubbed MockDio - that failure is caught and logged inside
    // AnalyticsService.flush() itself, so it doesn't propagate here.
    await sl<AnalyticsService>().flush();
  });
}
