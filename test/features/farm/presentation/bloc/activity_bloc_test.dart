import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActivityRepository extends Mock implements ActivityRepository {}

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

  late MockActivityRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(activity());
  });

  setUp(() {
    mockRepository = MockActivityRepository();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  ActivityBloc buildBloc() => ActivityBloc(repository: mockRepository);

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<ActivityBloc, ActivityState>(
      'GetActivitiesEvent emits [ActivityLoading, ActivityLoaded] from the '
      'repository',
      build: () {
        when(
          () => mockRepository.getActivities(
            sourceType: any(named: 'sourceType'),
          ),
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
          () => mockRepository.addActivity(any()),
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
          () => mockRepository.addActivity(any()),
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
          () => mockRepository.watchActivities(
            sourceType: any(named: 'sourceType'),
          ),
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
          () => mockRepository.watchActivities(sourceType: 'plant'),
        ).called(1);
      },
    );

    blocTest<ActivityBloc, ActivityState>(
      'dispatching WatchActivitiesEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchActivities(
            sourceType: any(named: 'sourceType'),
          ),
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
          () => mockRepository.watchActivities(
            sourceType: any(named: 'sourceType'),
          ),
        ).called(1);
      },
    );

    blocTest<ActivityBloc, ActivityState>(
      "AddActivityEvent success emits successMessage 'Activity recorded' "
      'using the stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addActivity(any()),
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
          () => mockRepository.updateActivity(any()),
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
          () => mockRepository.deleteActivity(any()),
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
          () => mockRepository.addActivity(any()),
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
          () => mockRepository.watchActivities(
            sourceType: any(named: 'sourceType'),
          ),
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
          () => mockRepository.watchActivities(
            sourceType: any(named: 'sourceType'),
          ),
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

  group('online infinite scroll (P3-02a, flag off)', () {
    blocTest<ActivityBloc, ActivityState>(
      'GetActivitiesEvent under a full page sets hasReachedMax true and '
      'derives nextCursor from the last id',
      build: () {
        when(
          () => mockRepository.getActivities(
            sourceType: any(named: 'sourceType'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => Right([activity(id: '3'), activity(id: '2')]),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetActivitiesEvent()),
      expect: () => [
        const ActivityLoading(),
        ActivityLoaded(
          activities: [activity(id: '3'), activity(id: '2')],
          nextCursor: 2,
        ),
      ],
    );

    blocTest<ActivityBloc, ActivityState>(
      'LoadMoreActivitiesEvent is a no-op when hasReachedMax (a ≤500-row '
      'account never issues a second fetch)',
      build: buildBloc,
      seed: () => ActivityLoaded(
        activities: [activity(id: '2')],
        nextCursor: 2,
      ),
      act: (bloc) => bloc.add(LoadMoreActivitiesEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => <ActivityState>[],
      verify: (_) {
        verifyNever(
          () => mockRepository.getActivities(
            sourceType: any(named: 'sourceType'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        );
      },
    );

    blocTest<ActivityBloc, ActivityState>(
      'a full first page sets hasReachedMax false; LoadMore fetches with the '
      'cursor, APPENDS the next page and recomputes hasReachedMax/nextCursor',
      build: () {
        final page1 = List.generate(
          kOnlineListPageSize,
          (i) => activity(id: '${1000 - i}'),
        );
        final page2 = [activity(id: '500'), activity(id: '499')];
        when(
          () => mockRepository.getActivities(
            sourceType: any(named: 'sourceType'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((invocation) async {
          final cursor = invocation.namedArguments[#cursor] as int?;
          return Right(cursor == null ? page1 : page2);
        });
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(GetActivitiesEvent());
        await bloc.stream.firstWhere((s) => s is ActivityLoaded);
        bloc.add(LoadMoreActivitiesEvent());
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const ActivityLoading(),
        isA<ActivityLoaded>()
            .having((s) => s.activities.length, 'page 1 length',
                kOnlineListPageSize)
            .having((s) => s.hasReachedMax, 'hasReachedMax', false)
            .having((s) => s.nextCursor, 'nextCursor', 501),
        isA<ActivityLoaded>()
            .having((s) => s.activities.length, 'appended length',
                kOnlineListPageSize + 2)
            .having((s) => s.hasReachedMax, 'hasReachedMax', true)
            .having((s) => s.nextCursor, 'nextCursor', 499),
      ],
      verify: (_) {
        verify(
          () => mockRepository.getActivities(
            sourceType: any(named: 'sourceType'),
            limit: any(named: 'limit'),
            cursor: 501,
          ),
        ).called(1);
      },
    );
  });
}
