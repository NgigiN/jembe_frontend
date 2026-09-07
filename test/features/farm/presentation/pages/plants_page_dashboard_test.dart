// Phase 8 B1: PlantsPage sources land/season/harvest COUNTS from
// GET /api/v1/dashboard on the online path instead of firing separate list
// GETs purely for a count, while the offline (OfflineConfig.enabled) path —
// which still has no dashboard mirror — is left untouched (its own
// Get/Watch* dispatches and per-bloc counts). Plant NAMES (for
// RelatedContentSection) and Content still come from their own fetches on
// both paths — the dashboard never covers those.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
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

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

Plant _plant(String id, String name) => Plant(
  id: id,
  userId: '1',
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

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
    registerFallbackValue(WatchSeasonsEvent());
    registerFallbackValue(GetHarvestsEvent());
    registerFallbackValue(WatchHarvestsEvent());
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
      initialState: PlantLoaded(plants: [_plant('1', 'Maize')]),
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

  Widget wrap() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LandBloc>.value(value: landBloc),
        BlocProvider<PlantBloc>.value(value: plantBloc),
        BlocProvider<SeasonBloc>.value(value: seasonBloc),
        BlocProvider<HarvestBloc>.value(value: harvestBloc),
        BlocProvider<ContentBloc>.value(value: contentBloc),
        BlocProvider<DashboardBloc>.value(value: dashboardBloc),
      ],
      child: const MaterialApp(home: PlantsPage()),
    );
  }

  group('online (OfflineConfig.enabled == false)', () {
    setUp(() {
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
      whenListen(
        dashboardBloc,
        const Stream<DashboardState>.empty(),
        initialState: const DashboardLoaded(
          counts: DashboardCounts(
            lands: 2,
            plants: 1,
            seasons: 3,
            harvests: 4,
            animalTypes: 0,
            herds: 0,
          ),
          totals: DashboardTotals.zero(),
        ),
      );
    });

    testWidgets(
      'dispatches GetDashboardEvent once (when not yet loaded) and never '
      'fires the land/season/harvest list GETs purely for counts',
      (tester) async {
        // Not-yet-loaded, so the initState guard actually dispatches -
        // the group `setUp` above pre-populates a DashboardLoaded for the
        // rendering tests below, which would otherwise skip the dispatch.
        whenListen(
          dashboardBloc,
          const Stream<DashboardState>.empty(),
          initialState: const DashboardInitial(),
        );

        await tester.pumpWidget(wrap());
        await tester.pump();

        verify(() => dashboardBloc.add(GetDashboardEvent())).called(1);
        verifyNever(() => landBloc.add(any(that: isA<GetLandsEvent>())));
        verifyNever(() => seasonBloc.add(any(that: isA<GetSeasonsEvent>())));
        verifyNever(
          () => harvestBloc.add(any(that: isA<GetHarvestsEvent>())),
        );
      },
    );

    testWidgets(
      'renders land/season/harvest counts from the dashboard, not from '
      'Land/Season/HarvestBloc',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.text('2 lands registered'), findsOneWidget);
        expect(find.text('3 seasons created'), findsOneWidget);

        await tester.dragUntilVisible(
          find.text('4 harvests recorded'),
          find.byType(ListView),
          const Offset(0, -300),
        );
        expect(find.text('4 harvests recorded'), findsOneWidget);
      },
    );

    testWidgets('plant count/names still come from PlantBloc', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('1 plants registered'), findsOneWidget);
    });
  });

  group('offline (OfflineConfig.enabled == true) - unchanged', () {
    setUp(() {
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
      whenListen(
        dashboardBloc,
        const Stream<DashboardState>.empty(),
        initialState: const DashboardInitial(),
      );
    });

    testWidgets(
      'dispatches the existing Get/Watch* events and never touches the '
      'DashboardBloc',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pump();

        verify(() => landBloc.add(any(that: isA<GetLandsEvent>()))).called(1);
        verify(
          () => seasonBloc.add(any(that: isA<WatchSeasonsEvent>())),
        ).called(1);
        verify(
          () => harvestBloc.add(any(that: isA<WatchHarvestsEvent>())),
        ).called(1);
        verifyNever(() => dashboardBloc.add(any(that: isA<GetDashboardEvent>())));
      },
    );
  });
}
