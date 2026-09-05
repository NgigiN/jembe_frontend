import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_activities.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_activities_params.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_activities.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetActivities extends Mock implements GetActivities {}

class MockAddActivity extends Mock implements AddActivity {}

class MockUpdateActivity extends Mock implements UpdateActivity {}

class MockDeleteActivity extends Mock implements DeleteActivity {}

class MockWatchActivities extends Mock implements WatchActivities {}

void main() {
  final now = DateTime.now();
  Activity activity({String id = 'activity-1', double cost = 100}) =>
      Activity(
        id: id,
        sourceType: 'plant',
        sourceId: 'season-1',
        type: 'Weeding',
        cost: cost,
        date: now,
        createdAt: now,
        updatedAt: now,
      );

  late MockGetActivities mockGetActivities;
  late MockAddActivity mockAddActivity;
  late MockUpdateActivity mockUpdateActivity;
  late MockDeleteActivity mockDeleteActivity;
  late MockWatchActivities mockWatchActivities;

  setUpAll(() {
    registerFallbackValue(GetActivitiesParams());
    registerFallbackValue(AddActivityParams(activity: activity()));
    registerFallbackValue(UpdateActivityParams(activity: activity()));
    registerFallbackValue(DeleteActivityParams(id: 'activity-1'));
  });

  setUp(() {
    mockGetActivities = MockGetActivities();
    mockAddActivity = MockAddActivity();
    mockUpdateActivity = MockUpdateActivity();
    mockDeleteActivity = MockDeleteActivity();
    mockWatchActivities = MockWatchActivities();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  ActivityBloc buildBloc() => ActivityBloc(
    getActivities: mockGetActivities,
    addActivity: mockAddActivity,
    updateActivity: mockUpdateActivity,
    deleteActivity: mockDeleteActivity,
    watchActivities: mockWatchActivities,
  );

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<ActivityBloc, ActivityState>(
      'GetActivitiesEvent emits [ActivityLoading, ActivityLoaded] from the '
      'use case',
      build: () {
        when(
          () => mockGetActivities(any()),
        ).thenAnswer((_) async => Right([activity()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetActivitiesEvent()),
      expect: () => [
        const ActivityLoading(),
        ActivityLoaded(activities: [activity()]),
      ],
    );

    blocTest<ActivityBloc, ActivityState>(
      "AddActivityEvent success appends the returned activity and sets "
      "successMessage 'Activity recorded'",
      build: () {
        when(
          () => mockAddActivity(any()),
        ).thenAnswer((_) async => Right(activity(id: 'activity-2')));
        return buildBloc();
      },
      seed: () => ActivityLoaded(activities: [activity()]),
      act: (bloc) => bloc.add(AddActivityEvent(activity(id: 'activity-2'))),
      expect: () => [
        isA<ActivityLoading>(),
        ActivityLoaded(
          activities: [activity(), activity(id: 'activity-2')],
          successMessage: 'Activity recorded',
        ),
      ],
    );

    blocTest<ActivityBloc, ActivityState>(
      'AddActivityEvent failure emits ActivityError preserving current '
      'activities',
      build: () {
        when(
          () => mockAddActivity(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => ActivityLoaded(activities: [activity()]),
      act: (bloc) => bloc.add(AddActivityEvent(activity(id: 'activity-2'))),
      expect: () => [
        isA<ActivityLoading>(),
        ActivityError('boom', activities: [activity()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<ActivityBloc, ActivityState>(
      'WatchActivitiesEvent subscribes to '
      'repository.watchActivities(sourceType:) and emits ActivityLoaded '
      'per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchActivities(sourceType: any(named: 'sourceType')),
        ).thenAnswer((_) => Stream.value([activity()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchActivitiesEvent(sourceType: 'plant')),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        ActivityLoaded(activities: [activity()]),
      ],
      verify: (_) {
        verify(
          () => mockWatchActivities(sourceType: 'plant'),
        ).called(1);
      },
    );

    blocTest<ActivityBloc, ActivityState>(
      'dispatching WatchActivitiesEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchActivities(sourceType: any(named: 'sourceType')),
        ).thenAnswer((_) => Stream.value([activity()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchActivitiesEvent())
          ..add(WatchActivitiesEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(
          () => mockWatchActivities(sourceType: any(named: 'sourceType')),
        ).called(1);
      },
    );

    blocTest<ActivityBloc, ActivityState>(
      "AddActivityEvent success emits successMessage 'Activity recorded' "
      'using the stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddActivity(any()),
        ).thenAnswer((_) async => Right(activity(id: 'activity-2')));
        return buildBloc();
      },
      seed: () => ActivityLoaded(activities: [activity()]),
      act: (bloc) => bloc.add(AddActivityEvent(activity(id: 'activity-2'))),
      expect: () => [
        ActivityLoaded(
          activities: [activity()],
          successMessage: 'Activity recorded',
        ),
      ],
    );

    blocTest<ActivityBloc, ActivityState>(
      "UpdateActivityEvent success emits successMessage 'Activity updated' "
      'without manually replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockUpdateActivity(any()),
        ).thenAnswer((_) async => Right(activity(cost: 999)));
        return buildBloc();
      },
      seed: () => ActivityLoaded(activities: [activity()]),
      act: (bloc) => bloc.add(UpdateActivityEvent(activity(cost: 999))),
      expect: () => [
        ActivityLoaded(
          activities: [activity()],
          successMessage: 'Activity updated',
        ),
      ],
    );

    blocTest<ActivityBloc, ActivityState>(
      "DeleteActivityEvent success emits successMessage 'Activity deleted' "
      'without manually removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockDeleteActivity(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => ActivityLoaded(activities: [activity()]),
      act: (bloc) => bloc.add(DeleteActivityEvent('activity-1')),
      expect: () => [
        ActivityLoaded(
          activities: [activity()],
          successMessage: 'Activity deleted',
        ),
      ],
    );

    blocTest<ActivityBloc, ActivityState>(
      'AddActivityEvent failure emits ActivityError preserving current '
      'activities',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddActivity(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => ActivityLoaded(activities: [activity()]),
      act: (bloc) => bloc.add(AddActivityEvent(activity(id: 'activity-2'))),
      expect: () => [
        ActivityError('boom', activities: [activity()]),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Activity>> controller;

    setUp(() {
      controller = StreamController<List<Activity>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<ActivityBloc, ActivityState>(
      'a stream error emits a non-fatal ActivityError over the last known '
      'activities without crashing the bloc, and the subscription stays '
      'alive for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchActivities(sourceType: any(named: 'sourceType')),
        ).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => ActivityLoaded(activities: [activity()]),
      act: (bloc) async {
        bloc.add(WatchActivitiesEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([activity(id: 'activity-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        ActivityError(
          'Live sync interrupted. Pull to refresh.',
          activities: [activity()],
        ),
        ActivityLoaded(activities: [activity(id: 'activity-2')]),
      ],
    );

    blocTest<ActivityBloc, ActivityState>(
      'a completed stream (onDone) does not emit any state or crash the '
      'bloc',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchActivities(sourceType: any(named: 'sourceType')),
        ).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => ActivityLoaded(activities: [activity()]),
      act: (bloc) async {
        bloc.add(WatchActivitiesEvent());
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      wait: const Duration(milliseconds: 50),
      expect: () => <ActivityState>[],
    );
  });
}
