import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_console_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _FakeFarmBloc extends Fake implements FarmBloc {
  _FakeFarmBloc(this._state);
  final FarmState _state;
  @override
  FarmState get state => _state;
  @override
  Stream<FarmState> get stream => Stream.value(_state);
}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Farm _farm(FarmRole role) => Farm(
  id: 1, name: 'Farm', location: '', fiscalYearStartMonth: 1,
  ownerUserId: 1, successorUserId: null, maxMembers: 5,
  role: role, memberCount: 1, isDefault: true,
);

Widget _harness(FarmRole role, {AuthBloc? authBloc}) {
  final router = GoRouter(
    initialLocation: WebRoutePath.dashboard,
    routes: [
      ShellRoute(
        builder: (context, state, child) => WebConsoleShell(child: child),
        routes: [
          GoRoute(path: WebRoutePath.dashboard, builder: (_, __) => const Text('dashboard-content')),
          GoRoute(path: WebRoutePath.feed, builder: (_, __) => const Text('feed-content')),
          GoRoute(path: WebRoutePath.members, builder: (_, __) => const Text('members-content')),
          GoRoute(path: WebRoutePath.reports, builder: (_, __) => const Text('reports-content')),
        ],
      ),
    ],
  );
  final resolvedAuthBloc = authBloc ?? MockAuthBloc();
  if (authBloc == null) {
    whenListen(
      resolvedAuthBloc as MockAuthBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthInitial(),
    );
  }
  return MultiBlocProvider(
    providers: [
      BlocProvider<FarmBloc>.value(
        value: _FakeFarmBloc(FarmLoaded(farms: [_farm(role)], currentFarmId: 1, currentRole: role)),
      ),
      BlocProvider<AuthBloc>.value(value: resolvedAuthBloc),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(LogoutEvent()));

  testWidgets('owner sees all four destinations', (tester) async {
    await tester.pumpWidget(_harness(FarmRole.owner));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('worker sees Feed and Members only', (tester) async {
    await tester.pumpWidget(_harness(FarmRole.worker));
    await tester.pumpAndSettle();
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Reports'), findsNothing);
  });

  testWidgets('shows the current farm name in the app bar', (tester) async {
    final authBloc = MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(), initialState: AuthInitial());
    await tester.pumpWidget(_harness(FarmRole.owner, authBloc: authBloc));
    await tester.pumpAndSettle();

    expect(find.text('Farm'), findsOneWidget); // _farm() in this file names it 'Farm'
  });

  testWidgets('sign-out button dispatches LogoutEvent', (tester) async {
    final authBloc = MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(), initialState: AuthInitial());
    await tester.pumpWidget(_harness(FarmRole.owner, authBloc: authBloc));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();

    verify(() => authBloc.add(any(that: isA<LogoutEvent>()))).called(1);
  });
}
