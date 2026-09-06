// Mirrors `herd_page_initstate_test.dart`'s shape: `RevenuePage.initState`
// must dispatch `WatchRevenuesEvent` (on `RevenueBloc`) when the offline
// flag is on, and the legacy one-shot `LoadRevenues` when it is off —
// never both, never neither. Unlike `HerdPage`, `RevenuePage` always
// re-fetches on mount (no "already loaded" guard — see its own initState
// doc: `RevenueBloc` is a singleton and the source filter isn't recorded on
// `RevenueLoaded`, so skipping a re-fetch could leave a stale,
// differently-filtered list on screen).
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/revenue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRevenueBloc extends MockBloc<RevenueEvent, RevenueState>
    implements RevenueBloc {}

Widget _wrap(RevenueBloc bloc) {
  return BlocProvider<RevenueBloc>.value(
    value: bloc,
    child: const MaterialApp(home: RevenuePage()),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(LoadRevenues());
    registerFallbackValue(WatchRevenuesEvent());
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    testWidgets(
      'dispatches the one-shot LoadRevenues(source: null) on mount',
      (tester) async {
        final bloc = MockRevenueBloc();
        whenListen(
          bloc,
          const Stream<RevenueState>.empty(),
          initialState: RevenueInitial(),
        );

        await tester.pumpWidget(_wrap(bloc));

        verify(
          () => bloc.add(
            any(
              that: isA<LoadRevenues>().having(
                (e) => e.source,
                'source',
                isNull,
              ),
            ),
          ),
        ).called(1);
        verifyNever(() => bloc.add(any(that: isA<WatchRevenuesEvent>())));
      },
    );

    testWidgets(
      'still dispatches LoadRevenues on mount even when revenues are '
      'already loaded (no "already loaded" guard on this page)',
      (tester) async {
        final bloc = MockRevenueBloc();
        whenListen(
          bloc,
          const Stream<RevenueState>.empty(),
          initialState: const RevenueLoaded(),
        );

        await tester.pumpWidget(_wrap(bloc));

        verify(() => bloc.add(any(that: isA<LoadRevenues>()))).called(1);
      },
    );
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets(
      'dispatches WatchRevenuesEvent(source: null) instead of LoadRevenues',
      (tester) async {
        OfflineConfig.enabled = true;
        final bloc = MockRevenueBloc();
        whenListen(
          bloc,
          const Stream<RevenueState>.empty(),
          initialState: RevenueInitial(),
        );

        await tester.pumpWidget(_wrap(bloc));

        verify(
          () => bloc.add(
            any(
              that: isA<WatchRevenuesEvent>().having(
                (e) => e.source,
                'source',
                isNull,
              ),
            ),
          ),
        ).called(1);
        verifyNever(() => bloc.add(any(that: isA<LoadRevenues>())));
      },
    );
  });
}
