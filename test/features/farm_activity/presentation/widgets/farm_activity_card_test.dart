import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/widgets/lively_tap.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/streak_page.dart';
import 'package:farm_tracker/features/farm_activity/presentation/widgets/farm_activity_card.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockHerdBloc extends MockBloc<HerdEvent, HerdState>
    implements HerdBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockActivityBloc extends MockBloc<ActivityEvent, ActivityState>
    implements ActivityBloc {}

class MockInputBloc extends MockBloc<InputEvent, InputState>
    implements InputBloc {}

class MockHarvestBloc extends MockBloc<HarvestEvent, HarvestState>
    implements HarvestBloc {}

class MockRevenueBloc extends MockBloc<RevenueEvent, RevenueState>
    implements RevenueBloc {}

class MockDio extends Mock implements Dio {}

final _now = DateTime(2026, 8, 24);

Herd _herd(String id) => Herd(
  id: id,
  userId: 'u',
  name: 'Herd $id',
  animalTypeId: 'a',
  location: 'x',
  initialHeadCount: 1,
  currentHeadCount: 1,
  startDate: _now,
  createdAt: _now,
  updatedAt: _now,
);

Activity _activityFor(String sourceType, String sourceId, DateTime createdAt) =>
    Activity(
      id: 'act-${createdAt.toIso8601String()}',
      sourceType: sourceType,
      sourceId: sourceId,
      type: 'x',
      cost: 0,
      date: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

void main() {
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    // A proper no-op stub: the real AnalyticsService.flush() posts here on
    // its 30s timer/size threshold, and initState() always fires a
    // 'farm_activity_viewed' track() call. Previously this registered a
    // bare, unstubbed MockDio - flush()'s internal try/catch silently
    // swallowed the resulting mocktail error, so these tests never actually
    // exercised (or asserted on) real analytics behavior. Stubbing a
    // success response here lets each test verify the real POST instead.
    when(
      () => mockDio.post<void>(any(), data: any(named: 'data')),
    ).thenAnswer(
      (_) async =>
          Response<void>(requestOptions: RequestOptions(), statusCode: 201),
    );
    sl.registerLazySingleton<AnalyticsService>(
      () => AnalyticsService(dio: mockDio),
    );
  });

  tearDown(() {
    sl.unregister<AnalyticsService>();
  });

  /// Flushes the buffered analytics event and asserts the real POST that
  /// `FarmActivityCard.initState()` fires on every pump: exactly one
  /// request to `/api/v1/events` carrying a `farm_activity_viewed` event.
  Future<void> flushAndVerifyAnalytics() async {
    await sl<AnalyticsService>().flush();

    final captured = verify(
      () => mockDio.post<void>(
        '/api/v1/events',
        data: captureAny(named: 'data'),
      ),
    ).captured;
    final body = captured.single as Map<String, dynamic>;
    final events = body['events'] as List;
    expect(events, hasLength(1));
    expect(events.single['name'], 'farm_activity_viewed');
  }

  testWidgets('renders nothing when the farmer has no herds and no seasons', (
    tester,
  ) async {
    final herdBloc = MockHerdBloc();
    final seasonBloc = MockSeasonBloc();
    final activityBloc = MockActivityBloc();
    final inputBloc = MockInputBloc();
    final harvestBloc = MockHarvestBloc();
    final revenueBloc = MockRevenueBloc();

    whenListen(
      herdBloc,
      Stream<HerdState>.value(HerdInitial()),
      initialState: HerdInitial(),
    );
    whenListen(
      seasonBloc,
      Stream<SeasonState>.value(SeasonInitial()),
      initialState: SeasonInitial(),
    );
    whenListen(
      activityBloc,
      Stream<ActivityState>.value(ActivityInitial()),
      initialState: ActivityInitial(),
    );
    whenListen(
      inputBloc,
      Stream<InputState>.value(InputInitial()),
      initialState: InputInitial(),
    );
    whenListen(
      harvestBloc,
      Stream<HarvestState>.value(HarvestInitial()),
      initialState: HarvestInitial(),
    );
    whenListen(
      revenueBloc,
      Stream<RevenueState>.value(RevenueInitial()),
      initialState: RevenueInitial(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<HerdBloc>.value(value: herdBloc),
          BlocProvider<SeasonBloc>.value(value: seasonBloc),
          BlocProvider<ActivityBloc>.value(value: activityBloc),
          BlocProvider<InputBloc>.value(value: inputBloc),
          BlocProvider<HarvestBloc>.value(value: harvestBloc),
          BlocProvider<RevenueBloc>.value(value: revenueBloc),
        ],
        child: const MaterialApp(home: Scaffold(body: FarmActivityCard())),
      ),
    );

    expect(find.byType(Card), findsNothing);

    // FarmActivityCard.initState() calls AnalyticsService.track(), which
    // schedules a real 30s flush Timer. flutter_test's
    // AutomatedTestWidgetsFlutterBinding asserts no Timer is left pending
    // when a test ends, so drain it explicitly here rather than waiting.
    await flushAndVerifyAnalytics();
  });

  testWidgets(
    'renders nothing while any bloc is still settling, even if another bloc '
    'already has real data (regression: no partial-data score flash)',
    (tester) async {
      final herdBloc = MockHerdBloc();
      final seasonBloc = MockSeasonBloc();
      final activityBloc = MockActivityBloc();
      final inputBloc = MockInputBloc();
      final harvestBloc = MockHarvestBloc();
      final revenueBloc = MockRevenueBloc();

      final herd = Herd(
        id: 'h1',
        userId: 'u1',
        name: 'Herd 1',
        animalTypeId: 'a1',
        location: 'x',
        initialHeadCount: 1,
        currentHeadCount: 1,
        startDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      // HerdBloc has already loaded real data...
      whenListen(
        herdBloc,
        Stream<HerdState>.value(HerdLoaded([herd])),
        initialState: HerdLoaded([herd]),
      );
      whenListen(
        seasonBloc,
        Stream<SeasonState>.value(const SeasonLoaded(seasons: [])),
        initialState: const SeasonLoaded(seasons: []),
      );
      // ...but ActivityBloc is still loading. The card must not compute or
      // show a score from the partial data it already has.
      whenListen(
        activityBloc,
        Stream<ActivityState>.value(const ActivityLoading()),
        initialState: const ActivityLoading(),
      );
      whenListen(
        inputBloc,
        Stream<InputState>.value(const InputLoaded(inputs: [])),
        initialState: const InputLoaded(inputs: []),
      );
      whenListen(
        harvestBloc,
        Stream<HarvestState>.value(const HarvestLoaded(harvests: [])),
        initialState: const HarvestLoaded(harvests: []),
      );
      whenListen(
        revenueBloc,
        Stream<RevenueState>.value(const RevenueLoaded()),
        initialState: const RevenueLoaded(),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<HerdBloc>.value(value: herdBloc),
            BlocProvider<SeasonBloc>.value(value: seasonBloc),
            BlocProvider<ActivityBloc>.value(value: activityBloc),
            BlocProvider<InputBloc>.value(value: inputBloc),
            BlocProvider<HarvestBloc>.value(value: harvestBloc),
            BlocProvider<RevenueBloc>.value(value: revenueBloc),
          ],
          child: const MaterialApp(home: Scaffold(body: FarmActivityCard())),
        ),
      );

      // Even though HerdBloc already has real data, ActivityBloc hasn't
      // settled yet, so the card must not compute or show a score - it
      // should render nothing (SizedBox.shrink()), not a partial-data card.
      expect(find.byType(Card), findsNothing);

      await flushAndVerifyAnalytics();
    },
  );

  group('when settled with a real level', () {
    Future<void> pumpSettled(
      WidgetTester tester, {
      required List<Herd> herds,
      required List<Activity> activities,
    }) async {
      final herdBloc = MockHerdBloc();
      final seasonBloc = MockSeasonBloc();
      final activityBloc = MockActivityBloc();
      final inputBloc = MockInputBloc();
      final harvestBloc = MockHarvestBloc();
      final revenueBloc = MockRevenueBloc();

      whenListen(
        herdBloc,
        Stream<HerdState>.value(HerdLoaded(herds)),
        initialState: HerdLoaded(herds),
      );
      whenListen(
        seasonBloc,
        Stream<SeasonState>.value(const SeasonLoaded(seasons: [])),
        initialState: const SeasonLoaded(seasons: []),
      );
      whenListen(
        activityBloc,
        Stream<ActivityState>.value(ActivityLoaded(activities: activities)),
        initialState: ActivityLoaded(activities: activities),
      );
      whenListen(
        inputBloc,
        Stream<InputState>.value(const InputLoaded(inputs: [])),
        initialState: const InputLoaded(inputs: []),
      );
      whenListen(
        harvestBloc,
        Stream<HarvestState>.value(const HarvestLoaded(harvests: [])),
        initialState: const HarvestLoaded(harvests: []),
      );
      whenListen(
        revenueBloc,
        Stream<RevenueState>.value(const RevenueLoaded()),
        initialState: const RevenueLoaded(),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<HerdBloc>.value(value: herdBloc),
            BlocProvider<SeasonBloc>.value(value: seasonBloc),
            BlocProvider<ActivityBloc>.value(value: activityBloc),
            BlocProvider<InputBloc>.value(value: inputBloc),
            BlocProvider<HarvestBloc>.value(value: harvestBloc),
            BlocProvider<RevenueBloc>.value(value: revenueBloc),
          ],
          child: MaterialApp(
            home: Scaffold(body: FarmActivityCard(now: _now)),
          ),
        ),
      );
    }

    testWidgets(
      'renders as a tappable analysis-style tile with icon, label, and Tap to view',
      (tester) async {
        await pumpSettled(
          tester,
          herds: [_herd('h1')],
          activities: [_activityFor('animal', 'h1', _now)],
        );

        expect(find.text('Thriving'), findsOneWidget);
        expect(find.text('Tap to view'), findsOneWidget);
        expect(find.byIcon(Icons.eco), findsOneWidget);
        expect(find.byType(InkWell), findsWidgets);
        expect(find.byType(LivelyTap), findsOneWidget);

        await flushAndVerifyAnalytics();
      },
    );

    testWidgets('still shows the weekly streak subtitle', (tester) async {
      await pumpSettled(
        tester,
        herds: [_herd('h1')],
        activities: [_activityFor('animal', 'h1', _now)],
      );

      expect(find.text('1-week streak'), findsOneWidget);

      await flushAndVerifyAnalytics();
    });
  });

  group('navigation', () {
    testWidgets('tapping the card pushes the streak page', (tester) async {
      final herdBloc = MockHerdBloc();
      final seasonBloc = MockSeasonBloc();
      final activityBloc = MockActivityBloc();
      final inputBloc = MockInputBloc();
      final harvestBloc = MockHarvestBloc();
      final revenueBloc = MockRevenueBloc();

      whenListen(
        herdBloc,
        Stream<HerdState>.value(HerdLoaded([_herd('h1')])),
        initialState: HerdLoaded([_herd('h1')]),
      );
      whenListen(
        seasonBloc,
        Stream<SeasonState>.value(const SeasonLoaded(seasons: [])),
        initialState: const SeasonLoaded(seasons: []),
      );
      whenListen(
        activityBloc,
        Stream<ActivityState>.value(
          ActivityLoaded(activities: [_activityFor('animal', 'h1', _now)]),
        ),
        initialState: ActivityLoaded(
          activities: [_activityFor('animal', 'h1', _now)],
        ),
      );
      whenListen(
        inputBloc,
        Stream<InputState>.value(const InputLoaded(inputs: [])),
        initialState: const InputLoaded(inputs: []),
      );
      whenListen(
        harvestBloc,
        Stream<HarvestState>.value(const HarvestLoaded(harvests: [])),
        initialState: const HarvestLoaded(harvests: []),
      );
      whenListen(
        revenueBloc,
        Stream<RevenueState>.value(const RevenueLoaded()),
        initialState: const RevenueLoaded(),
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: FarmActivityCard(now: _now)),
          ),
          GoRoute(
            name: AppRouteName.streak,
            path: AppRoutePath.streak,
            builder: (context, state) => const StreakPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<HerdBloc>.value(value: herdBloc),
            BlocProvider<SeasonBloc>.value(value: seasonBloc),
            BlocProvider<ActivityBloc>.value(value: activityBloc),
            BlocProvider<InputBloc>.value(value: inputBloc),
            BlocProvider<HarvestBloc>.value(value: harvestBloc),
            BlocProvider<RevenueBloc>.value(value: revenueBloc),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.text('Farm Activity Streak'), findsOneWidget);

      await flushAndVerifyAnalytics();
    });
  });
}
