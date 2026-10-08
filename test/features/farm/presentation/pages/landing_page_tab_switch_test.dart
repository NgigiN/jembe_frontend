import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
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

/// Tab switching through the real shell.
///
/// The existing landing-page harness registers a single route inside its
/// `ShellRoute`, so the tab index never changes and [LandingPage]'s
/// `ValueKey(index)` never remounts `AdaptiveScaffoldPlus`. That remount is
/// the interesting path: go_router hands the shell its navigator already
/// wrapped in a `PopScope`, and that navigator carries a
/// `GlobalObjectKey(navigatorKey.hashCode)`. Moving it between parents is
/// what a keyed remount does, and a GlobalKey that ends up in two live
/// parents at once truncates part of the tree instead of throwing in
/// release.
///
/// These cases exercise that remount with five tabs registered, at the real
/// device's metrics. They do NOT reproduce the duplicate-GlobalKey assertion
/// observed once on device on 8 Oct 2026 — that trigger is still unknown.
/// They close the coverage gap that let such a thing go unseen by the suite.
class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _FakeFarmBloc extends Fake implements FarmBloc {
  @override
  FarmState get state => const FarmLoaded(
    farms: [
      Farm(
        id: 1,
        name: 'Farm',
        location: '',
        fiscalYearStartMonth: 1,
        ownerUserId: 1,
        successorUserId: null,
        maxMembers: 5,
        role: FarmRole.owner,
        memberCount: 1,
        isDefault: true,
      ),
    ],
    currentFarmId: 1,
    currentRole: FarmRole.owner,
  );
  @override
  Stream<FarmState> get stream => Stream.value(state);
}

const _fakeUser = User(
  id: 'u',
  email: 'a@b.c',
  firstName: 'A',
  lastName: 'B',
  farmName: 'F',
  location: 'L',
  pictureUrl: '',
);

late GoRouter _router;

/// Mirrors the app's shell: every top-level tab registered, so the resolved
/// index moves and the keyed remount actually happens.
Widget _harness(AuthBloc authBloc) {
  _router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => LandingPage(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('plants')),
          GoRoute(path: '/animals', builder: (_, __) => const Text('animals')),
          GoRoute(path: '/revenue', builder: (_, __) => const Text('revenue')),
          GoRoute(path: '/analytics', builder: (_, __) => const Text('an')),
          GoRoute(path: '/settings', builder: (_, __) => const Text('set')),
        ],
      ),
    ],
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<FarmBloc>.value(value: _FakeFarmBloc()),
    ],
    child: MaterialApp.router(routerConfig: _router),
  );
}

void main() {
  late MockAuthBloc authBloc;

  setUp(() {
    OfflineConfig.enabled = false;
    authBloc = MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(_fakeUser),
    );
  });

  /// The real device this was investigated on: 1080x2372 at dpr 3.0, which
  /// is 360 logical px wide — the compact branch. The test default of 800px
  /// lands in the medium branch and exercises different layout code.
  void useDeviceMetrics(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2372);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('switching tabs swaps the content and throws nothing', (
    tester,
  ) async {
    useDeviceMetrics(tester);
    await tester.pumpWidget(_harness(authBloc));
    await tester.pumpAndSettle();
    expect(find.text('plants'), findsOneWidget);

    _router.go('/animals');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: 'mid tab transition');

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after tab transition');
    expect(find.text('animals'), findsOneWidget);
    expect(find.text('plants'), findsNothing);
  });

  testWidgets('crossing a layout breakpoint throws nothing', (tester) async {
    useDeviceMetrics(tester);
    await tester.pumpWidget(_harness(authBloc));
    await tester.pumpAndSettle();

    // Compact -> expanded, as a rotation or a foldable unfolding would do.
    tester.view.physicalSize = const Size(2400, 1800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: 'mid breakpoint change');

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after breakpoint change');
    expect(find.text('plants'), findsOneWidget);
  });
}
