// Mirrors `plant_page_initstate_test.dart`'s shape: `HarvestPage.initState`
// must dispatch `WatchHarvestsEvent(seasonId:)` when the offline flag is on,
// and the legacy one-shot `GetHarvestsEvent(seasonId:)` when it is off —
// never both, never neither — passing the same `widget.seasonId` filter
// either way.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/harvest_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHarvestBloc extends MockBloc<HarvestEvent, HarvestState>
    implements HarvestBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

Widget _wrap(HarvestBloc bloc, SeasonBloc seasonBloc, {String? seasonId}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<HarvestBloc>.value(value: bloc),
      BlocProvider<SeasonBloc>.value(value: seasonBloc),
    ],
    child: MaterialApp(home: HarvestPage(seasonId: seasonId)),
  );
}

void main() {
  late MockSeasonBloc seasonBloc;

  setUpAll(() {
    registerFallbackValue(GetHarvestsEvent());
    registerFallbackValue(WatchHarvestsEvent());
  });

  setUp(() {
    seasonBloc = MockSeasonBloc();
    whenListen(
      seasonBloc,
      const Stream<SeasonState>.empty(),
      initialState: const SeasonLoaded(seasons: []),
    );
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    testWidgets('does not refetch when harvests already loaded', (
      tester,
    ) async {
      final bloc = MockHarvestBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<HarvestState>.empty(),
        initialState: HarvestLoaded(
          harvests: [
            Harvest(
              id: 'harvest-1',
              seasonId: 'season-1',
              quantity: 10,
              unit: 'kg',
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _wrap(bloc, seasonBloc, seasonId: 'season-1'),
      );

      verifyNever(() => bloc.add(any(that: isA<GetHarvestsEvent>())));
      verifyNever(() => bloc.add(any(that: isA<WatchHarvestsEvent>())));
    });

    testWidgets(
      'dispatches the one-shot GetHarvestsEvent(seasonId:) when not yet '
      'loaded',
      (tester) async {
        final bloc = MockHarvestBloc();
        whenListen(
          bloc,
          const Stream<HarvestState>.empty(),
          initialState: HarvestInitial(),
        );

        await tester.pumpWidget(
          _wrap(bloc, seasonBloc, seasonId: 'season-1'),
        );

        final captured = verify(
          () => bloc.add(captureAny(that: isA<GetHarvestsEvent>())),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.single as GetHarvestsEvent).seasonId, 'season-1');
        verifyNever(() => bloc.add(any(that: isA<WatchHarvestsEvent>())));
      },
    );
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets(
      'dispatches WatchHarvestsEvent(seasonId:) instead of GetHarvestsEvent',
      (tester) async {
        OfflineConfig.enabled = true;
        final bloc = MockHarvestBloc();
        whenListen(
          bloc,
          const Stream<HarvestState>.empty(),
          initialState: HarvestInitial(),
        );

        await tester.pumpWidget(
          _wrap(bloc, seasonBloc, seasonId: 'season-1'),
        );

        final captured = verify(
          () => bloc.add(captureAny(that: isA<WatchHarvestsEvent>())),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.single as WatchHarvestsEvent).seasonId, 'season-1');
        verifyNever(() => bloc.add(any(that: isA<GetHarvestsEvent>())));
      },
    );

    testWidgets('does not re-watch when harvests already loaded', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockHarvestBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<HarvestState>.empty(),
        initialState: HarvestLoaded(
          harvests: [
            Harvest(
              id: 'harvest-1',
              seasonId: 'season-1',
              quantity: 10,
              unit: 'kg',
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _wrap(bloc, seasonBloc, seasonId: 'season-1'),
      );

      verifyNever(() => bloc.add(any(that: isA<WatchHarvestsEvent>())));
      verifyNever(() => bloc.add(any(that: isA<GetHarvestsEvent>())));
    });
  });
}
