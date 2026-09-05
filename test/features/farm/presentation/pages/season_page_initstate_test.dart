// Mirrors `land_page_refetch_test.dart`'s "fetches when not yet loaded"
// shape, extended with the `OfflineConfig.enabled` gate added in Task 6's
// fix round 1: `SeasonPage.initState` must dispatch `WatchSeasonsEvent` when
// the offline flag is on, and the legacy one-shot `GetSeasonsEvent` when it
// is off — never both, never neither. `LandBloc`/`PlantBloc` are seeded
// already-loaded so their own (out-of-scope-for-this-fix / already-loaded)
// dispatches don't interfere with the SeasonBloc assertions below.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/season_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState>
    implements LandBloc {}

class MockPlantBloc extends MockBloc<PlantEvent, PlantState>
    implements PlantBloc {}

Widget _wrap({
  required SeasonBloc seasonBloc,
  required LandBloc landBloc,
  required PlantBloc plantBloc,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<SeasonBloc>.value(value: seasonBloc),
        BlocProvider<LandBloc>.value(value: landBloc),
        BlocProvider<PlantBloc>.value(value: plantBloc),
      ],
      child: const SeasonPage(),
    ),
  );
}

void main() {
  final now = DateTime.now();
  final loadedLand = LandLoaded(
    lands: [
      Land(
        id: 'land-1',
        userId: 'user-1',
        name: 'North Field',
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
  final loadedPlant = PlantLoaded(
    plants: [
      Plant(id: 'plant-1', userId: 'user-1', name: 'Maize', createdAt: now, updatedAt: now),
    ],
  );

  setUpAll(() {
    registerFallbackValue(GetSeasonsEvent());
    registerFallbackValue(WatchSeasonsEvent());
    registerFallbackValue(GetLandsEvent());
    registerFallbackValue(GetPlantsEvent());
    registerFallbackValue(WatchPlantsEvent());
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    testWidgets('does not refetch when seasons already loaded', (
      tester,
    ) async {
      final seasonBloc = MockSeasonBloc();
      final landBloc = MockLandBloc();
      final plantBloc = MockPlantBloc();
      whenListen(
        seasonBloc,
        const Stream<SeasonState>.empty(),
        initialState: SeasonLoaded(
          seasons: [
            Season(
              id: 'season-1',
              userId: 'user-1',
              name: 'Long Rains',
              plantId: 'plant-1',
              landId: 'land-1',
              startDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );
      whenListen(
        landBloc,
        const Stream<LandState>.empty(),
        initialState: loadedLand,
      );
      whenListen(
        plantBloc,
        const Stream<PlantState>.empty(),
        initialState: loadedPlant,
      );

      await tester.pumpWidget(
        _wrap(seasonBloc: seasonBloc, landBloc: landBloc, plantBloc: plantBloc),
      );

      verifyNever(() => seasonBloc.add(any(that: isA<GetSeasonsEvent>())));
      verifyNever(() => seasonBloc.add(any(that: isA<WatchSeasonsEvent>())));
    });

    testWidgets(
      'dispatches the one-shot GetSeasonsEvent when not yet loaded',
      (tester) async {
        final seasonBloc = MockSeasonBloc();
        final landBloc = MockLandBloc();
        final plantBloc = MockPlantBloc();
        whenListen(
          seasonBloc,
          const Stream<SeasonState>.empty(),
          initialState: SeasonInitial(),
        );
        whenListen(
          landBloc,
          const Stream<LandState>.empty(),
          initialState: loadedLand,
        );
        whenListen(
          plantBloc,
          const Stream<PlantState>.empty(),
          initialState: loadedPlant,
        );

        await tester.pumpWidget(
          _wrap(seasonBloc: seasonBloc, landBloc: landBloc, plantBloc: plantBloc),
        );

        verify(
          () => seasonBloc.add(any(that: isA<GetSeasonsEvent>())),
        ).called(1);
        verifyNever(() => seasonBloc.add(any(that: isA<WatchSeasonsEvent>())));
      },
    );
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets('dispatches WatchSeasonsEvent instead of GetSeasonsEvent', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final seasonBloc = MockSeasonBloc();
      final landBloc = MockLandBloc();
      final plantBloc = MockPlantBloc();
      whenListen(
        seasonBloc,
        const Stream<SeasonState>.empty(),
        initialState: SeasonInitial(),
      );
      whenListen(
        landBloc,
        const Stream<LandState>.empty(),
        initialState: loadedLand,
      );
      whenListen(
        plantBloc,
        const Stream<PlantState>.empty(),
        initialState: loadedPlant,
      );

      await tester.pumpWidget(
        _wrap(seasonBloc: seasonBloc, landBloc: landBloc, plantBloc: plantBloc),
      );

      verify(
        () => seasonBloc.add(any(that: isA<WatchSeasonsEvent>())),
      ).called(1);
      verifyNever(() => seasonBloc.add(any(that: isA<GetSeasonsEvent>())));
    });

    testWidgets('does not re-watch when seasons already loaded', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final seasonBloc = MockSeasonBloc();
      final landBloc = MockLandBloc();
      final plantBloc = MockPlantBloc();
      whenListen(
        seasonBloc,
        const Stream<SeasonState>.empty(),
        initialState: SeasonLoaded(
          seasons: [
            Season(
              id: 'season-1',
              userId: 'user-1',
              name: 'Long Rains',
              plantId: 'plant-1',
              landId: 'land-1',
              startDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );
      whenListen(
        landBloc,
        const Stream<LandState>.empty(),
        initialState: loadedLand,
      );
      whenListen(
        plantBloc,
        const Stream<PlantState>.empty(),
        initialState: loadedPlant,
      );

      await tester.pumpWidget(
        _wrap(seasonBloc: seasonBloc, landBloc: landBloc, plantBloc: plantBloc),
      );

      verifyNever(() => seasonBloc.add(any(that: isA<WatchSeasonsEvent>())));
      verifyNever(() => seasonBloc.add(any(that: isA<GetSeasonsEvent>())));
    });
  });

  group('plant watch/get gate inside SeasonPage.initState', () {
    testWidgets(
      'dispatches WatchPlantsEvent (not GetPlantsEvent) when the flag is on '
      'and plants are not yet loaded',
      (tester) async {
        OfflineConfig.enabled = true;
        final seasonBloc = MockSeasonBloc();
        final landBloc = MockLandBloc();
        final plantBloc = MockPlantBloc();
        whenListen(
          seasonBloc,
          const Stream<SeasonState>.empty(),
          initialState: const SeasonLoaded(seasons: []),
        );
        whenListen(
          landBloc,
          const Stream<LandState>.empty(),
          initialState: loadedLand,
        );
        whenListen(
          plantBloc,
          const Stream<PlantState>.empty(),
          initialState: PlantInitial(),
        );

        await tester.pumpWidget(
          _wrap(seasonBloc: seasonBloc, landBloc: landBloc, plantBloc: plantBloc),
        );

        verify(
          () => plantBloc.add(any(that: isA<WatchPlantsEvent>())),
        ).called(1);
        verifyNever(() => plantBloc.add(any(that: isA<GetPlantsEvent>())));
      },
    );

    testWidgets(
      'dispatches the one-shot GetPlantsEvent when the flag is off and '
      'plants are not yet loaded',
      (tester) async {
        final seasonBloc = MockSeasonBloc();
        final landBloc = MockLandBloc();
        final plantBloc = MockPlantBloc();
        whenListen(
          seasonBloc,
          const Stream<SeasonState>.empty(),
          initialState: const SeasonLoaded(seasons: []),
        );
        whenListen(
          landBloc,
          const Stream<LandState>.empty(),
          initialState: loadedLand,
        );
        whenListen(
          plantBloc,
          const Stream<PlantState>.empty(),
          initialState: PlantInitial(),
        );

        await tester.pumpWidget(
          _wrap(seasonBloc: seasonBloc, landBloc: landBloc, plantBloc: plantBloc),
        );

        verify(
          () => plantBloc.add(any(that: isA<GetPlantsEvent>())),
        ).called(1);
        verifyNever(() => plantBloc.add(any(that: isA<WatchPlantsEvent>())));
      },
    );
  });
}
