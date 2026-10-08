// PR #60 established the rule for first-run blank screens: with the offline
// mirror on, a page must SUBSCRIBE rather than read once, and must do so even
// when the bloc already holds a loaded list, because that list can be the
// empty one produced by a read that landed before the first sync finished.
//
// It applied the rule to this page's plant dispatch and left the
// land/season/harvest block below it alone. Lands kept a one-shot
// GetLandsEvent, and seasons and harvests kept the `state is! XLoaded` guard
// the rule exists to remove.
//
// That shipped. On 2026-10-08, with OFFLINE_ENABLED flipped on in production,
// this page showed "Register your farmland" against a server holding four
// lands, while seasons and plants rendered correctly, and the sync indicator
// read "Synced just now" throughout: the mirror had the rows, the page had
// read it once too early and never looked again.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
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
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/farm_bloc_stub.dart';

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockPlantBloc extends MockBloc<PlantEvent, PlantState>
    implements PlantBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockHarvestBloc extends MockBloc<HarvestEvent, HarvestState>
    implements HarvestBloc {}

class MockContentBloc extends MockBloc<ContentEvent, ContentState>
    implements ContentBloc {}

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  late MockLandBloc landBloc;
  late MockPlantBloc plantBloc;
  late MockSeasonBloc seasonBloc;
  late MockHarvestBloc harvestBloc;
  late MockContentBloc contentBloc;
  late MockDashboardBloc dashboardBloc;

  setUpAll(() {
    registerFallbackValue(GetLandsEvent());
    registerFallbackValue(GetSeasonsEvent());
    registerFallbackValue(GetHarvestsEvent());
    registerFallbackValue(GetPlantsEvent());
    registerFallbackValue(GetAllContentEvent());
    registerFallbackValue(GetDashboardEvent());
  });

  setUp(() {
    landBloc = MockLandBloc();
    plantBloc = MockPlantBloc();
    seasonBloc = MockSeasonBloc();
    harvestBloc = MockHarvestBloc();
    contentBloc = MockContentBloc();
    dashboardBloc = MockDashboardBloc();

    whenListen(
      plantBloc,
      const Stream<PlantState>.empty(),
      initialState: const PlantLoaded(plants: []),
    );
    whenListen(
      contentBloc,
      const Stream<ContentState>.empty(),
      initialState: const ContentLoaded(items: []),
    );
    whenListen(
      dashboardBloc,
      const Stream<DashboardState>.empty(),
      initialState: const DashboardInitial(),
    );
  });

  tearDown(() => OfflineConfig.enabled = false);

  /// Every farm-scoped bloc already holds an EMPTY loaded list - the state a
  /// read that beat the first sync leaves behind.
  void seedAllEmptyLoaded() {
    whenListen(
      landBloc,
      const Stream<LandState>.empty(),
      initialState: const LandLoaded(lands: []),
    );
    whenListen(
      seasonBloc,
      const Stream<SeasonState>.empty(),
      initialState: const SeasonLoaded(seasons: []),
    );
    whenListen(
      harvestBloc,
      const Stream<HarvestState>.empty(),
      initialState: const HarvestLoaded(harvests: []),
    );
  }

  Widget wrap() => MultiBlocProvider(
    providers: [
      BlocProvider<FarmBloc>.value(value: stubFarmBloc()),
      BlocProvider<LandBloc>.value(value: landBloc),
      BlocProvider<PlantBloc>.value(value: plantBloc),
      BlocProvider<SeasonBloc>.value(value: seasonBloc),
      BlocProvider<HarvestBloc>.value(value: harvestBloc),
      BlocProvider<ContentBloc>.value(value: contentBloc),
      BlocProvider<DashboardBloc>.value(value: dashboardBloc),
    ],
    child: const MaterialApp(home: PlantsPage()),
  );

  testWidgets(
    'flag ON: subscribes to lands rather than reading once - the one-shot '
    'read is what showed "Register your farmland" against four real lands',
    (tester) async {
      OfflineConfig.enabled = true;
      seedAllEmptyLoaded();

      await tester.pumpWidget(wrap());

      verify(() => landBloc.add(any(that: isA<WatchLandsEvent>()))).called(1);
      verifyNever(() => landBloc.add(any(that: isA<GetLandsEvent>())));
    },
  );

  testWidgets(
    'flag ON: subscribes to seasons and harvests even when each bloc already '
    'holds an empty loaded list',
    (tester) async {
      OfflineConfig.enabled = true;
      seedAllEmptyLoaded();

      await tester.pumpWidget(wrap());

      verify(
        () => seasonBloc.add(any(that: isA<WatchSeasonsEvent>())),
      ).called(1);
      verify(
        () => harvestBloc.add(any(that: isA<WatchHarvestsEvent>())),
      ).called(1);
    },
  );

  testWidgets('flag ON: subscribes from a cold start too', (tester) async {
    OfflineConfig.enabled = true;
    whenListen(
      landBloc,
      const Stream<LandState>.empty(),
      initialState: LandInitial(),
    );
    whenListen(
      seasonBloc,
      const Stream<SeasonState>.empty(),
      initialState: SeasonInitial(),
    );
    whenListen(
      harvestBloc,
      const Stream<HarvestState>.empty(),
      initialState: HarvestInitial(),
    );

    await tester.pumpWidget(wrap());

    verify(() => landBloc.add(any(that: isA<WatchLandsEvent>()))).called(1);
  });

  testWidgets(
    'flag OFF: the online path is untouched - counts come from the dashboard '
    'and nothing subscribes to the mirror',
    (tester) async {
      OfflineConfig.enabled = false;
      seedAllEmptyLoaded();

      await tester.pumpWidget(wrap());

      verify(
        () => dashboardBloc.add(any(that: isA<GetDashboardEvent>())),
      ).called(1);
      verifyNever(() => landBloc.add(any(that: isA<WatchLandsEvent>())));
      verifyNever(() => landBloc.add(any(that: isA<GetLandsEvent>())));
    },
  );
}
