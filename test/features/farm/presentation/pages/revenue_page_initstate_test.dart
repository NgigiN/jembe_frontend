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
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/revenue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRevenueBloc extends MockBloc<RevenueEvent, RevenueState>
    implements RevenueBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

/// One land ('Shamba A', l1) with one season (s1) on it, no herds — enough
/// for the chip row and the offline land → season-id resolution.
Widget _wrap(RevenueBloc bloc) {
  final lands = MockLandBloc();
  final herds = MockHerdBloc();
  final seasons = MockSeasonBloc();
  final land = Land(
    id: 'l1',
    userId: 'u',
    name: 'Shamba A',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final season = Season(
    id: 's1',
    userId: 'u',
    name: 'Long Rains 2026',
    plantId: 'p1',
    landId: 'l1',
    startDate: DateTime(2026, 3),
    createdAt: DateTime(2026, 3),
    updatedAt: DateTime(2026, 3),
  );
  whenListen(
    lands,
    Stream<LandState>.value(LandLoaded(lands: [land])),
    initialState: LandLoaded(lands: [land]),
  );
  whenListen(
    herds,
    Stream<HerdState>.value(const HerdLoaded([])),
    initialState: const HerdLoaded([]),
  );
  whenListen(
    seasons,
    Stream<SeasonState>.value(SeasonLoaded(seasons: [season])),
    initialState: SeasonLoaded(seasons: [season]),
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<RevenueBloc>.value(value: bloc),
      BlocProvider<LandBloc>.value(value: lands),
      BlocProvider<HerdBloc>.value(value: herds),
      BlocProvider<SeasonBloc>.value(value: seasons),
    ],
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
    testWidgets('dispatches the one-shot LoadRevenues(scope: all) on mount', (
      tester,
    ) async {
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
              (e) => e.scope,
              'scope',
              const AnalyticsScope.all(),
            ),
          ),
        ),
      ).called(1);
      verifyNever(() => bloc.add(any(that: isA<WatchRevenuesEvent>())));
    });

    testWidgets('still dispatches LoadRevenues on mount even when revenues are '
        'already loaded (no "already loaded" guard on this page)', (
      tester,
    ) async {
      final bloc = MockRevenueBloc();
      whenListen(
        bloc,
        const Stream<RevenueState>.empty(),
        initialState: const RevenueLoaded(),
      );

      await tester.pumpWidget(_wrap(bloc));

      verify(() => bloc.add(any(that: isA<LoadRevenues>()))).called(1);
    });
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets(
      'dispatches WatchRevenuesEvent(scope: all) instead of LoadRevenues',
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
                (e) => e.scope,
                'scope',
                const AnalyticsScope.all(),
              ),
            ),
          ),
        ).called(1);
        verifyNever(() => bloc.add(any(that: isA<LoadRevenues>())));
      },
    );
  });

  group('scope chips (spec 2026-09-08)', () {
    testWidgets(
      'flag OFF: tapping Plants then a land re-fetches with the land scope',
      (tester) async {
        final bloc = MockRevenueBloc();
        whenListen(
          bloc,
          const Stream<RevenueState>.empty(),
          initialState: RevenueInitial(),
        );
        await tester.pumpWidget(_wrap(bloc));

        await tester.tap(find.text('Plants'));
        await tester.pumpAndSettle();
        verify(
          () => bloc.add(
            any(
              that: isA<LoadRevenues>().having(
                (e) => e.scope,
                'scope',
                const AnalyticsScope.source(ScopeSource.plant),
              ),
            ),
          ),
        ).called(1);

        await tester.tap(find.text('Shamba A'));
        verify(
          () => bloc.add(
            any(
              that: isA<LoadRevenues>().having(
                (e) => e.scope,
                'scope',
                const AnalyticsScope.land('l1'),
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets("flag ON: a land scope passes that land's season ids to "
        'WatchRevenuesEvent', (tester) async {
      OfflineConfig.enabled = true;
      final bloc = MockRevenueBloc();
      whenListen(
        bloc,
        const Stream<RevenueState>.empty(),
        initialState: RevenueInitial(),
      );
      await tester.pumpWidget(_wrap(bloc));

      await tester.tap(find.text('Plants'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shamba A'));
      verify(
        () => bloc.add(
          any(
            that: isA<WatchRevenuesEvent>()
                .having(
                  (e) => e.scope,
                  'scope',
                  const AnalyticsScope.land('l1'),
                )
                .having((e) => e.seasonIdsOnLand, 'seasonIdsOnLand', {'s1'}),
          ),
        ),
      ).called(1);
    });
  });
}
