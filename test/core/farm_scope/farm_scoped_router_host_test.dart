import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/farm_scope/farm_scoped_blocs.dart';
import 'package:farm_tracker/core/farm_scope/farm_scoped_router_host.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// What a farm switch has to do, exercised through a REAL go_router.
///
/// The bug these cover: go_router gives its Navigator a
/// `GlobalObjectKey(navigatorKey.hashCode)`, and Flutter reparents a GlobalKey
/// element rather than recreating it. Re-keying a subtree that merely CONTAINS
/// the Router therefore swaps the farm-scoped blocs while the Navigator — and
/// every page `State` under it — rides across untouched. `initState` never
/// runs again, so nothing refetches, and the page renders the farm the user
/// just left.
///
/// The fix is a new `GoRouter` per farm, so the navigatorKey identity changes
/// and no reparenting is possible. These tests are written against that
/// behaviour, not against the mechanism, so they stay honest if the mechanism
/// changes again.
class _MockFarmBloc extends MockBloc<FarmEvent, FarmState>
    implements FarmBloc {}

class _Dummy extends Cubit<int> {
  _Dummy() : super(0);
}

FarmLoaded _loaded(int? id) =>
    FarmLoaded(farms: const [], currentFarmId: id, currentRole: FarmRole.owner);

/// Stands in for a page whose `initState` fires the farm-scoped fetch. The
/// mount count IS the number of times that fetch would have run.
class _CountingPage extends StatefulWidget {
  const _CountingPage(this.label, this.onMount);

  final String label;
  final VoidCallback onMount;

  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

void main() {
  late StreamController<FarmState> states;
  late _MockFarmBloc farmBloc;
  late int plantsMounts;
  late int revenueMounts;

  setUp(() {
    plantsMounts = 0;
    revenueMounts = 0;
    states = StreamController<FarmState>.broadcast();
    farmBloc = _MockFarmBloc();
    whenListen(farmBloc, states.stream, initialState: FarmInitial());
  });

  tearDown(() async => states.close());

  /// The app's own wiring: a shell, tabs, farm-scoped providers between the
  /// MaterialApp and the Navigator.
  GoRouter buildRouter(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          body: child,
          bottomNavigationBar: const SizedBox(height: 8),
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => _CountingPage('plants', () => plantsMounts++),
          ),
          GoRoute(
            path: '/revenue',
            builder: (_, __) => _CountingPage('revenue', () => revenueMounts++),
          ),
        ],
      ),
    ],
  );

  Future<void> emit(WidgetTester tester, FarmState state) async {
    states.add(state);
    await tester.pump(Duration.zero);
    await tester.pumpAndSettle();
  }

  Widget harness() => MultiBlocProvider(
    providers: [BlocProvider<FarmBloc>.value(value: farmBloc)],
    child: FarmScopedRouterHost(
      initialLocation: '/',
      createRouter: buildRouter,
      builder: (context, router) => MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => FarmScopedBlocs(
          providers: [BlocProvider<_Dummy>(create: (_) => _Dummy())],
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );

  testWidgets(
    'a genuine farm switch remounts the page, so its initState refetches',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await emit(tester, _loaded(7));

      expect(plantsMounts, 1, reason: 'adopting the first id is not a switch');

      await emit(tester, _loaded(9));

      expect(
        plantsMounts,
        2,
        reason:
            'without a remount the page never refetches and renders the '
            'farm the user just left',
      );
    },
  );

  testWidgets('the switch keeps the user on the tab they were on', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await emit(tester, _loaded(7));

    tester.state<NavigatorState>(find.byType(Navigator).first);
    // Move to a non-default tab the way the shell does.
    final BuildContext ctx = tester.element(find.text('plants'));
    GoRouter.of(ctx).go('/revenue');
    await tester.pumpAndSettle();
    expect(find.text('revenue'), findsOneWidget);
    expect(revenueMounts, 1);

    await emit(tester, _loaded(9));

    expect(
      find.text('revenue'),
      findsOneWidget,
      reason: 'a switch must not throw the user back to the first tab',
    );
    expect(revenueMounts, 2, reason: 'the retained tab still remounts');
  });

  testWidgets(
    'a ScaffoldMessenger captured BEFORE the switch still works after it - '
    'the switcher grabs the messenger, dispatches SwitchFarm, then shows the '
    '"Switched to ..." confirmation, so rebuilding MaterialApp would throw '
    'away the only feedback the feature gives',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await emit(tester, _loaded(7));

      final messenger = ScaffoldMessenger.of(
        tester.element(find.text('plants')),
      );

      await emit(tester, _loaded(9));

      messenger.showSnackBar(
        const SnackBar(content: Text('Switched to Kamukunji')),
      );
      await tester.pump();

      expect(find.text('Switched to Kamukunji'), findsOneWidget);
    },
  );

  testWidgets(
    'the first resolved farm id is adopted WITHOUT a rebuild - a cold start '
    'must not fetch everything twice just because LoadFarms resolves a frame '
    'after the tree is built',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(plantsMounts, 1);

      await emit(tester, _loaded(7));

      expect(plantsMounts, 1);
    },
  );

  testWidgets('re-emitting the same farm id changes nothing', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await emit(tester, _loaded(7));

    await emit(tester, _loaded(7));
    await emit(tester, _loaded(7));

    expect(plantsMounts, 1);
  });

  testWidgets(
    'a null current farm id is ignored - it means "not resolved yet", never '
    '"no farm", and must not tear the tree down mid-load',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await emit(tester, _loaded(7));

      await emit(tester, _loaded(null));

      expect(plantsMounts, 1);
    },
  );
}
