import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _fakeUser = User(
  id: 'user-1',
  email: 'a@example.com',
  firstName: 'A',
  lastName: 'B',
  farmName: 'Farm',
  location: 'Somewhere',
  pictureUrl: '',
);

/// Full 5-destination router, matching main.dart's real routes.dart shell
/// wiring, so tapping a destination exercises the actual _onTabSelected
/// switch in LandingPage rather than a single dummy route.
Widget _harness(AuthBloc authBloc) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => LandingPage(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('plants-content')),
          GoRoute(path: AppRoutePath.analytics, builder: (_, __) => const Text('analytics-content')),
          GoRoute(path: AppRoutePath.animals, builder: (_, __) => const Text('animals-content')),
          GoRoute(path: AppRoutePath.revenue, builder: (_, __) => const Text('revenue-content')),
          GoRoute(path: AppRoutePath.settingsPage, builder: (_, __) => const Text('settings-content')),
        ],
      ),
    ],
  );

  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late MockAuthBloc authBloc;

  setUp(() {
    authBloc = MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(_fakeUser),
    );
  });

  testWidgets('renders the 5 tab destinations and the routed child', (tester) async {
    await tester.pumpWidget(_harness(authBloc));
    await tester.pumpAndSettle();

    expect(find.text('plants-content'), findsOneWidget);
    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Animals'));
    await tester.pumpAndSettle();
    expect(find.text('animals-content'), findsOneWidget);
  });
}
