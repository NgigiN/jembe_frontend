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

/// Pumps the shell at a width where the sidebar shows its labels. Below
/// ConsoleMetrics.shellBreakpoint it collapses to icons, and the default
/// 800x600 test surface would hide every label under test.
Future<void> _pumpShell(
  WidgetTester tester,
  FarmRole role, {
  AuthBloc? authBloc,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_harness(role, authBloc: authBloc));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(LogoutEvent()));


  testWidgets('owner sees every destination', (tester) async {
    await _pumpShell(tester, FarmRole.owner);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Farms'), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('a worker does not see the staff-only destinations', (
    tester,
  ) async {
    await _pumpShell(tester, FarmRole.worker);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Farms'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    // Absent, not greyed out (DESIGN_SPEC §5).
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Trash'), findsNothing);
  });

  testWidgets('the farm switcher names the current farm and role', (
    tester,
  ) async {
    await _pumpShell(tester, FarmRole.owner);

    // _farm() in this file names it 'Farm'.
    expect(find.text('Farm'), findsOneWidget);
    expect(find.textContaining('Owner'), findsWidgets);
  });

  testWidgets('sign-out button dispatches LogoutEvent', (tester) async {
    final authBloc = MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(), initialState: AuthInitial());
    await _pumpShell(tester, FarmRole.owner, authBloc: authBloc);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();

    verify(() => authBloc.add(any(that: isA<LogoutEvent>()))).called(1);
  });
}
