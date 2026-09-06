// Focused on the one initState dispatch this task must gate:
// `PlantsPage.initState` also dispatches an UNFILTERED `GetHarvestsEvent()`
// (see the task-7a brief) — it must become `WatchHarvestsEvent()` flag-on,
// and stay `GetHarvestsEvent()` flag-off, exactly like every other
// `GetXEvent()` initState site. The other blocs this page reads
// (Land/Plant/Season/Content) are pre-loaded here so only the harvest gate
// is under test.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/plants_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockPlantBloc extends MockBloc<PlantEvent, PlantState>
    implements PlantBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockHarvestBloc extends MockBloc<HarvestEvent, HarvestState>
    implements HarvestBloc {}

class MockContentBloc extends MockBloc<ContentEvent, ContentState>
    implements ContentBloc {}

Widget _wrap({
  required LandBloc landBloc,
  required PlantBloc plantBloc,
  required SeasonBloc seasonBloc,
  required HarvestBloc harvestBloc,
  required ContentBloc contentBloc,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<LandBloc>.value(value: landBloc),
      BlocProvider<PlantBloc>.value(value: plantBloc),
      BlocProvider<SeasonBloc>.value(value: seasonBloc),
      BlocProvider<HarvestBloc>.value(value: harvestBloc),
      BlocProvider<ContentBloc>.value(value: contentBloc),
    ],
    child: const MaterialApp(home: PlantsPage()),
  );
}

void main() {
  late MockLandBloc landBloc;
  late MockPlantBloc plantBloc;
  late MockSeasonBloc seasonBloc;
  late MockContentBloc contentBloc;

  setUpAll(() {
    registerFallbackValue(GetHarvestsEvent());
    registerFallbackValue(WatchHarvestsEvent());
  });

  setUp(() {
    landBloc = MockLandBloc();
    plantBloc = MockPlantBloc();
    seasonBloc = MockSeasonBloc();
    contentBloc = MockContentBloc();
    whenListen(
      landBloc,
      const Stream<LandState>.empty(),
      initialState: const LandLoaded(lands: []),
    );
    whenListen(
      plantBloc,
      const Stream<PlantState>.empty(),
      initialState: const PlantLoaded(plants: []),
    );
    whenListen(
      seasonBloc,
      const Stream<SeasonState>.empty(),
      initialState: const SeasonLoaded(seasons: []),
    );
    whenListen(
      contentBloc,
      const Stream<ContentState>.empty(),
      initialState: const ContentLoaded(items: []),
    );
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  testWidgets(
    'flag OFF: dispatches the one-shot unfiltered GetHarvestsEvent when not '
    'yet loaded',
    (tester) async {
      final harvestBloc = MockHarvestBloc();
      whenListen(
        harvestBloc,
        const Stream<HarvestState>.empty(),
        initialState: HarvestInitial(),
      );

      await tester.pumpWidget(
        _wrap(
          landBloc: landBloc,
          plantBloc: plantBloc,
          seasonBloc: seasonBloc,
          harvestBloc: harvestBloc,
          contentBloc: contentBloc,
        ),
      );

      final captured = verify(
        () => harvestBloc.add(captureAny(that: isA<GetHarvestsEvent>())),
      ).captured;
      expect(captured, hasLength(1));
      expect((captured.single as GetHarvestsEvent).seasonId, isNull);
      verifyNever(() => harvestBloc.add(any(that: isA<WatchHarvestsEvent>())));
    },
  );

  testWidgets(
    'flag ON: dispatches the unfiltered WatchHarvestsEvent instead of '
    'GetHarvestsEvent',
    (tester) async {
      OfflineConfig.enabled = true;
      final harvestBloc = MockHarvestBloc();
      whenListen(
        harvestBloc,
        const Stream<HarvestState>.empty(),
        initialState: HarvestInitial(),
      );

      await tester.pumpWidget(
        _wrap(
          landBloc: landBloc,
          plantBloc: plantBloc,
          seasonBloc: seasonBloc,
          harvestBloc: harvestBloc,
          contentBloc: contentBloc,
        ),
      );

      final captured = verify(
        () => harvestBloc.add(captureAny(that: isA<WatchHarvestsEvent>())),
      ).captured;
      expect(captured, hasLength(1));
      expect((captured.single as WatchHarvestsEvent).seasonId, isNull);
      verifyNever(() => harvestBloc.add(any(that: isA<GetHarvestsEvent>())));
    },
  );

  testWidgets('does not re-fetch/re-watch when harvests already loaded', (
    tester,
  ) async {
    final harvestBloc = MockHarvestBloc();
    whenListen(
      harvestBloc,
      const Stream<HarvestState>.empty(),
      initialState: const HarvestLoaded(harvests: []),
    );

    await tester.pumpWidget(
      _wrap(
        landBloc: landBloc,
        plantBloc: plantBloc,
        seasonBloc: seasonBloc,
        harvestBloc: harvestBloc,
        contentBloc: contentBloc,
      ),
    );

    verifyNever(() => harvestBloc.add(any(that: isA<GetHarvestsEvent>())));
    verifyNever(() => harvestBloc.add(any(that: isA<WatchHarvestsEvent>())));
  });
}
