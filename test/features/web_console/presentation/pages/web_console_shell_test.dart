import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_console_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeFarmBloc extends Fake implements FarmBloc {
  _FakeFarmBloc(this._state);
  final FarmState _state;
  @override
  FarmState get state => _state;
  @override
  Stream<FarmState> get stream => Stream.value(_state);
}

Farm _farm(FarmRole role) => Farm(
  id: 1, name: 'Farm', location: '', fiscalYearStartMonth: 1,
  ownerUserId: 1, successorUserId: null, maxMembers: 5,
  role: role, memberCount: 1, isDefault: true,
);

Widget _harness(FarmRole role) {
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
  return BlocProvider<FarmBloc>.value(
    value: _FakeFarmBloc(FarmLoaded(farms: [_farm(role)], currentFarmId: 1, currentRole: role)),
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
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
}
