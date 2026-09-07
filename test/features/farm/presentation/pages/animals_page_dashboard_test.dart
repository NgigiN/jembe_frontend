// Phase 8 B1: AnimalsPage sources the herd COUNT from GET /api/v1/dashboard
// on the online path instead of a second list GET fired purely for a count,
// while the offline (OfflineConfig.enabled) path — which still has no
// dashboard mirror — is left untouched (HerdBloc's own GetHerdsEvent and
// count, exactly as before the dashboard existed). Animal-type NAMES (for
// RelatedContentSection) and Content still come from their own fetches on
// both paths.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockContentBloc extends MockBloc<ContentEvent, ContentState>
    implements ContentBloc {}

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  late MockAnimalTypeBloc animalTypeBloc;
  late MockHerdBloc herdBloc;
  late MockContentBloc contentBloc;
  late MockDashboardBloc dashboardBloc;

  setUpAll(() {
    registerFallbackValue(GetAnimalTypesEvent());
    registerFallbackValue(GetHerdsEvent());
    registerFallbackValue(GetDashboardEvent());
  });

  setUp(() {
    animalTypeBloc = MockAnimalTypeBloc();
    herdBloc = MockHerdBloc();
    contentBloc = MockContentBloc();
    dashboardBloc = MockDashboardBloc();
    whenListen(
      animalTypeBloc,
      const Stream<AnimalTypeState>.empty(),
      initialState: const AnimalTypeLoaded([]),
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
        BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
        BlocProvider<HerdBloc>.value(value: herdBloc),
        BlocProvider<ContentBloc>.value(value: contentBloc),
        BlocProvider<DashboardBloc>.value(value: dashboardBloc),
      ],
      child: const MaterialApp(home: AnimalsPage()),
    );
  }

  group('online (OfflineConfig.enabled == false)', () {
    setUp(() {
      whenListen(
        herdBloc,
        const Stream<HerdState>.empty(),
        initialState: HerdInitial(),
      );
      whenListen(
        dashboardBloc,
        const Stream<DashboardState>.empty(),
        initialState: const DashboardLoaded(
          counts: DashboardCounts(
            lands: 0,
            plants: 0,
            seasons: 0,
            harvests: 0,
            animalTypes: 0,
            herds: 9,
          ),
          totals: DashboardTotals.zero(),
        ),
      );
    });

    testWidgets(
      'dispatches GetDashboardEvent once (when not yet loaded) and never '
      'fires GetHerdsEvent purely for the count',
      (tester) async {
        // Not-yet-loaded, so the initState guard actually dispatches - the
        // group `setUp` above pre-populates a DashboardLoaded for the
        // rendering test below, which would otherwise skip the dispatch.
        whenListen(
          dashboardBloc,
          const Stream<DashboardState>.empty(),
          initialState: const DashboardInitial(),
        );

        await tester.pumpWidget(wrap());
        await tester.pump();

        verify(() => dashboardBloc.add(GetDashboardEvent())).called(1);
        verifyNever(() => herdBloc.add(any(that: isA<GetHerdsEvent>())));
      },
    );

    testWidgets('renders the herd count from the dashboard, not HerdBloc', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('9 herds registered'), findsOneWidget);
    });

    testWidgets(
      'renders the animal-type count from the dashboard, not '
      'AnimalTypeBloc (PR B review fix 2)',
      (tester) async {
        // AnimalTypeBloc only carries 2 types (e.g. capped by B3's
        // kOnlineListPageSize), but the dashboard says there are 7 — the
        // displayed count must be the dashboard's.
        whenListen(
          animalTypeBloc,
          const Stream<AnimalTypeState>.empty(),
          initialState: AnimalTypeLoaded([
            AnimalType(
              id: '1',
              userId: '1',
              name: 'Cow',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
            AnimalType(
              id: '2',
              userId: '1',
              name: 'Goat',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ]),
        );
        whenListen(
          dashboardBloc,
          const Stream<DashboardState>.empty(),
          initialState: const DashboardLoaded(
            counts: DashboardCounts(
              lands: 0,
              plants: 0,
              seasons: 0,
              harvests: 0,
              animalTypes: 7,
              herds: 9,
            ),
            totals: DashboardTotals.zero(),
          ),
        );

        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.text('7 types added'), findsOneWidget);
        expect(find.text('2 types added'), findsNothing);
      },
    );

    testWidgets(
      'a DashboardError degrades gracefully: the checklist and '
      'animal-type names still render, counts fall back to 0 (PR B '
      'review fix 3 parity)',
      (tester) async {
        whenListen(
          dashboardBloc,
          const Stream<DashboardState>.empty(),
          initialState: const DashboardError('network down'),
        );

        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.text('Could not load data'), findsNothing);
        expect(find.text('Add Animal Types'), findsOneWidget);
        expect(find.text('Animal Management'), findsOneWidget);
      },
    );
  });

  group('offline (OfflineConfig.enabled == true) - unchanged', () {
    setUp(() {
      OfflineConfig.enabled = true;
      whenListen(
        herdBloc,
        const Stream<HerdState>.empty(),
        initialState: HerdInitial(),
      );
      whenListen(
        dashboardBloc,
        const Stream<DashboardState>.empty(),
        initialState: const DashboardInitial(),
      );
    });

    testWidgets(
      'dispatches the existing GetHerdsEvent and never touches the '
      'DashboardBloc',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pump();

        verify(() => herdBloc.add(any(that: isA<GetHerdsEvent>()))).called(1);
        verifyNever(
          () => dashboardBloc.add(any(that: isA<GetDashboardEvent>())),
        );
      },
    );
  });
}
