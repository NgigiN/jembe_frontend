import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
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
import 'package:farm_tracker/features/farm_activity/presentation/widgets/farm_activity_card.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  setUp(() {
    sl.registerLazySingleton<AnalyticsService>(
      () => AnalyticsService(dio: MockDio()),
    );
  });

  tearDown(() {
    sl.unregister<AnalyticsService>();
  });

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
    // flush() cancels its own timer first, then (since the buffer isn't
    // empty) attempts a POST via the unstubbed MockDio - that failure is
    // caught and logged inside AnalyticsService.flush() itself, so it
    // doesn't propagate here.
    await sl<AnalyticsService>().flush();
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

      await sl<AnalyticsService>().flush();
    },
  );
}
