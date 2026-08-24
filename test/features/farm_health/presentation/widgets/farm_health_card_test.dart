import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
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
import 'package:farm_tracker/features/farm_health/presentation/widgets/farm_health_card.dart';
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
        child: const MaterialApp(home: Scaffold(body: FarmHealthCard())),
      ),
    );

    expect(find.byType(Card), findsNothing);

    // FarmHealthCard.initState() calls AnalyticsService.track(), which
    // schedules a real 30s flush Timer. flutter_test's
    // AutomatedTestWidgetsFlutterBinding asserts no Timer is left pending
    // when a test ends, so drain it explicitly here rather than waiting.
    // flush() cancels its own timer first, then (since the buffer isn't
    // empty) attempts a POST via the unstubbed MockDio - that failure is
    // caught and logged inside AnalyticsService.flush() itself, so it
    // doesn't propagate here.
    await sl<AnalyticsService>().flush();
  });
}
