import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/landing_page.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeFarmBloc extends Fake implements FarmBloc {
  _FakeFarmBloc(this._state);
  final FarmState _state;
  @override
  FarmState get state => _state;
  @override
  Stream<FarmState> get stream => Stream.value(_state);
}

const _fakeUser = User(
  id: 'user-1',
  email: 'a@example.com',
  firstName: 'A',
  lastName: 'B',
  farmName: 'Farm',
  location: 'Somewhere',
  pictureUrl: '',
);

Farm _farm(FarmRole role) => Farm(
  id: 1, name: 'Farm', location: '', fiscalYearStartMonth: 1,
  ownerUserId: 1, successorUserId: null, maxMembers: 5,
  role: role, memberCount: 1, isDefault: true,
);

/// Full 5-destination router, matching main.dart's real routes.dart shell
/// wiring, so tapping a destination exercises the actual _onTabSelected
/// switch in LandingPage rather than a single dummy route.
Widget _harness(AuthBloc authBloc, {FarmRole? role}) {
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

  final farmState = role == null
      ? FarmInitial()
      : FarmLoaded(farms: [_farm(role)], currentFarmId: 1, currentRole: role);

  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<FarmBloc>.value(value: _FakeFarmBloc(farmState)),
    ],
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
    await tester.pumpWidget(_harness(authBloc, role: FarmRole.owner));
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

  testWidgets('a worker sees Plants, Animals, Settings only — no Revenue '
      'or Analytics', (tester) async {
    await tester.pumpWidget(_harness(authBloc, role: FarmRole.worker));
    await tester.pumpAndSettle();

    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Revenue'), findsNothing);
    expect(find.text('Analytics'), findsNothing);
  });

  testWidgets('an unknown (not-yet-loaded) role shows all 5 destinations,'
      ' same as before this sub-project', (tester) async {
    await tester.pumpWidget(_harness(authBloc));
    await tester.pumpAndSettle();

    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
