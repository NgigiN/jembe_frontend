import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/audio/sound_service.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
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
import 'package:farm_tracker/features/farm/presentation/pages/analysis_page.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakeSoundPlayer implements SoundPlayer {
  final calls = <String>[];

  @override
  Future<void> play(String assetPath) async => calls.add(assetPath);
}

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

Season _season(String id) => Season(
  id: id,
  userId: 'u',
  name: 'Season $id',
  plantId: 'p',
  landId: 'l',
  startDate: _now,
  createdAt: _now,
  updatedAt: _now,
);

Activity _activityFor(String sourceType, String sourceId, DateTime createdAt) =>
    Activity(
      id: 'act-${createdAt.toIso8601String()}-$sourceId',
      sourceType: sourceType,
      sourceId: sourceId,
      type: 'x',
      cost: 0,
      date: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

Future<void> _pumpStreakPage(
  WidgetTester tester, {
  required List<Herd> herds,
  required List<Season> seasons,
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
    Stream<SeasonState>.value(SeasonLoaded(seasons: seasons)),
    initialState: SeasonLoaded(seasons: seasons),
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
      child: MaterialApp(home: StreakPage(now: _now)),
    ),
  );
}

void main() {
  testWidgets('shows a graceful message when there are no herds or seasons', (
    tester,
  ) async {
    await _pumpStreakPage(tester, herds: const [], seasons: const [], activities: const []);

    expect(find.text('Nothing to track yet'), findsOneWidget);
  });

  testWidgets('shows the level label and an explanation when everything is stale', (
    tester,
  ) async {
    final herd = _herd('h1');
    await _pumpStreakPage(
      tester,
      herds: [herd],
      seasons: const [],
      activities: [_activityFor('animal', 'h1', _now.subtract(const Duration(days: 90)))],
    );

    expect(find.text('Needs attention'), findsOneWidget);
    expect(
      find.text(
        "Several of your herds and seasons haven't had any activity, "
        'input, or harvest logged recently.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the weekly streak count with encouragement', (tester) async {
    final herd = _herd('h1');
    await _pumpStreakPage(
      tester,
      herds: [herd],
      seasons: const [],
      activities: [_activityFor('animal', 'h1', _now)],
    );

    expect(find.text('1-week streak'), findsOneWidget);
  });

  testWidgets(
    'lists breakdown items with stale ones showing days-ago and fresh ones showing active, stalest first',
    (tester) async {
      final stale = _herd('stale');
      final fresh = _season('fresh');
      await _pumpStreakPage(
        tester,
        herds: [stale],
        seasons: [fresh],
        activities: [
          _activityFor('animal', 'stale', _now.subtract(const Duration(days: 45))),
          _activityFor('plant', 'fresh', _now.subtract(const Duration(days: 3))),
        ],
      );

      expect(find.text('No activity in 45 days'), findsOneWidget);
      expect(find.text('Active 3 days ago'), findsOneWidget);

      final staleY = tester.getTopLeft(find.text('No activity in 45 days')).dy;
      final freshY = tester.getTopLeft(find.text('Active 3 days ago')).dy;
      expect(staleY, lessThan(freshY));
    },
  );

  testWidgets('shows a never-active herd as such', (tester) async {
    final never = _herd('never');
    await _pumpStreakPage(
      tester,
      herds: [never],
      seasons: const [],
      activities: const [],
    );

    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets(
    'fires a medium haptic and plays the success sound when reaching Thriving',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final player = _FakeSoundPlayer();
      sl.registerLazySingleton<SoundService>(
        () => SoundService(player: player),
      );
      addTearDown(() => sl.unregister<SoundService>());

      final herd = _herd('h1');
      await _pumpStreakPage(
        tester,
        herds: [herd],
        seasons: const [],
        activities: [_activityFor('animal', 'h1', _now)],
      );

      final hapticCalls =
          calls.where((c) => c.method == 'HapticFeedback.vibrate');
      expect(hapticCalls, hasLength(1));
      expect(
        hapticCalls.single.arguments,
        'HapticFeedbackType.mediumImpact',
      );
      expect(player.calls, ['sounds/success.mp3']);
    },
  );

  testWidgets(
    'does not refire when an unrelated bloc re-emits with the level unchanged',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final herd = _herd('h1');
      final herdBloc = MockHerdBloc();
      final seasonBloc = MockSeasonBloc();
      final activityBloc = MockActivityBloc();
      final inputBloc = MockInputBloc();
      final harvestBloc = MockHarvestBloc();
      final revenueBloc = MockRevenueBloc();
      final herdController = StreamController<HerdState>.broadcast();
      addTearDown(herdController.close);

      whenListen(
        herdBloc,
        herdController.stream,
        initialState: HerdLoaded([herd]),
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
          child: MaterialApp(home: StreakPage(now: _now)),
        ),
      );

      // Re-emit the identical herd state, simulating an unrelated bloc
      // rebuild that leaves the computed level unchanged.
      herdController.add(HerdLoaded([herd]));
      await tester.pump();

      final hapticCalls =
          calls.where((c) => c.method == 'HapticFeedback.vibrate');
      expect(hapticCalls, hasLength(1));
    },
  );

  testWidgets(
    'does not fire when the level never reaches Thriving',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final herd = _herd('h1');
      await _pumpStreakPage(
        tester,
        herds: [herd],
        seasons: const [],
        activities: [
          _activityFor('animal', 'h1', _now.subtract(const Duration(days: 90))),
        ],
      );

      final hapticCalls =
          calls.where((c) => c.method == 'HapticFeedback.vibrate');
      expect(hapticCalls, isEmpty);
    },
  );
}
