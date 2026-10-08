import 'package:farm_tracker/core/farm_scope/farm_scoped_blocs.dart';
import 'package:farm_tracker/core/farm_scope/farm_scoped_router_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// [FarmScopedBlocs] no longer decides WHEN a switch happened — that moved to
/// [FarmScopedRouterHost], which has to replace the router anyway and so is
/// the only place that can know. What is left here is narrow and worth
/// pinning: the providers are rebuilt when, and only when, the published
/// generation changes.
///
/// The "when only" half matters as much as the "when". Rebuilding on every
/// frame would throw away every farm-scoped bloc continuously; the generation
/// is what keeps that from happening.

/// Counts how many times a farm-scoped bloc was constructed.
class _CountingCubit extends Cubit<int> {
  _CountingCubit(VoidCallback onCreate) : super(0) {
    onCreate();
  }
}

/// Stands in for a page whose `initState` fires a farm-scoped fetch.
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

void main() {
  late int mounts;
  late int blocBuilds;

  setUp(() {
    mounts = 0;
    blocBuilds = 0;
  });

  Widget harness(int generation) => MaterialApp(
    home: FarmGeneration(
      generation: generation,
      child: FarmScopedBlocs(
        providers: [
          // lazy: false so the build is observable without a consumer — in
          // the app these are built on first read by a page.
          BlocProvider<_CountingCubit>(
            lazy: false,
            create: (_) => _CountingCubit(() => blocBuilds++),
          ),
        ],
        child: _MountCounter(() => mounts++),
      ),
    ),
  );

  testWidgets('provides the farm-scoped blocs on first build', (tester) async {
    await tester.pumpWidget(harness(0));

    expect(mounts, 1);
    expect(blocBuilds, 1);
  });

  testWidgets(
    'a new generation rebuilds the providers AND remounts the child, so the '
    'next farm gets fresh blocs and a fetch rather than the previous farm',
    (tester) async {
      await tester.pumpWidget(harness(0));

      await tester.pumpWidget(harness(1));

      expect(mounts, 2, reason: 'the page remounts, so initState refetches');
      expect(blocBuilds, 2, reason: "the old farm's blocs are discarded");
    },
  );

  testWidgets(
    'rebuilding at the same generation keeps the same blocs - otherwise every '
    'frame would discard the farm-scoped state',
    (tester) async {
      await tester.pumpWidget(harness(3));

      await tester.pumpWidget(harness(3));
      await tester.pumpWidget(harness(3));

      expect(mounts, 1);
      expect(blocBuilds, 1);
    },
  );

  testWidgets('defaults to generation 0 when no host is above it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FarmScopedBlocs(
          providers: [
            BlocProvider<_CountingCubit>(
              lazy: false,
              create: (_) => _CountingCubit(() => blocBuilds++),
            ),
          ],
          child: _MountCounter(() => mounts++),
        ),
      ),
    );

    expect(mounts, 1);
    expect(blocBuilds, 1);
  });
}
