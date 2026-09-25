import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/farm_scope/farm_scoped_blocs.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockFarmBloc extends MockBloc<FarmEvent, FarmState>
    implements FarmBloc {}

/// Stands in for a farm-scoped bloc: counts how many times one was built, so
/// a test can prove a switch really did hand the tree fresh instances rather
/// than the previous farm's.
class _CountingCubit extends Cubit<int> {
  _CountingCubit(VoidCallback onCreate) : super(0) {
    onCreate();
  }
}

/// Stands in for a page whose `initState` fires a farm-scoped fetch: counts
/// mounts, which is exactly the number of times that fetch would run.
class _MountCounter extends StatefulWidget {
  const _MountCounter(this.onMount);

  final VoidCallback onMount;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

FarmLoaded _loaded(int? id) =>
    FarmLoaded(farms: const [], currentFarmId: id, currentRole: FarmRole.owner);

void main() {
  late _MockFarmBloc farmBloc;
  late StreamController<FarmState> states;
  late int mounts;
  late int blocBuilds;

  setUp(() {
    mounts = 0;
    blocBuilds = 0;
    states = StreamController<FarmState>.broadcast();
    farmBloc = _MockFarmBloc();
    whenListen(farmBloc, states.stream, initialState: FarmInitial());
  });

  tearDown(() async {
    await states.close();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<FarmBloc>.value(
        value: farmBloc,
        child: FarmScopedBlocs(
          providers: [
            // lazy: false so the build is observable without a consumer —
            // in the app these are built on first read by a page.
            BlocProvider<_CountingCubit>(
              lazy: false,
              create: (_) => _CountingCubit(() => blocBuilds++),
            ),
          ],
          child: _MountCounter(() => mounts++),
        ),
      ),
    ),
  );

  /// Broadcast-stream delivery is a microtask, so a single pump can run the
  /// frame before the listener ever sees the event. Drain, then pump.
  Future<void> emit(WidgetTester tester, FarmState state) async {
    states.add(state);
    await tester.pump(Duration.zero);
    await tester.pump();
  }

  testWidgets(
    'adopts the first farm id WITHOUT remounting - a cold start must not '
    'fetch twice just because LoadFarms resolves after the first frame',
    (tester) async {
      await pump(tester);
      expect(mounts, 1);
      expect(blocBuilds, 1);

      await emit(tester, _loaded(7));

      expect(mounts, 1, reason: 'adopting the first id is not a switch');
      expect(blocBuilds, 1);
    },
  );

  testWidgets(
    'remounts the child and rebuilds the farm-scoped blocs when the farm '
    'actually changes - this is what makes a switch reload the data',
    (tester) async {
      await pump(tester);
      await emit(tester, _loaded(7));

      await emit(tester, _loaded(9));

      expect(mounts, 2, reason: 'the page remounts, so initState refetches');
      expect(blocBuilds, 2, reason: "the old farm's blocs are discarded");
    },
  );

  testWidgets('re-emitting the same farm id changes nothing', (tester) async {
    await pump(tester);
    await emit(tester, _loaded(7));

    await emit(tester, _loaded(7));
    await emit(tester, _loaded(7));

    expect(mounts, 1);
    expect(blocBuilds, 1);
  });

  testWidgets(
    'a null current farm id is ignored - it means "not resolved yet", not '
    '"no farm", and must never tear the subtree down',
    (tester) async {
      await pump(tester);
      await emit(tester, _loaded(7));

      await emit(tester, _loaded(null));

      expect(mounts, 1);
      expect(blocBuilds, 1);
    },
  );

  testWidgets('a non-FarmLoaded state is ignored', (tester) async {
    await pump(tester);
    await emit(tester, _loaded(7));

    await emit(tester, const FarmError('offline'));

    expect(mounts, 1);
    expect(blocBuilds, 1);
  });
}
