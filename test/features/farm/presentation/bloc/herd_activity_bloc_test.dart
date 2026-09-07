import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_herd_activity.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAddHerdActivity extends Mock implements AddHerdActivity {}

void main() {
  final now = DateTime.utc(2026, 9);

  HerdActivity herdActivity({
    String id = 'activity-1',
    String herdId = 'herd-1',
    String activityType = 'birth',
    int count = 2,
    String? notes,
  }) => HerdActivity(
    id: id,
    herdId: herdId,
    activityType: activityType,
    count: count,
    date: now,
    createdAt: now,
    notes: notes,
  );

  late MockAddHerdActivity mockAddHerdActivity;

  setUp(() {
    mockAddHerdActivity = MockAddHerdActivity();
  });

  HerdActivityBloc buildBloc() =>
      HerdActivityBloc(addHerdActivity: mockAddHerdActivity);

  group('AddHerdActivityEvent', () {
    blocTest<HerdActivityBloc, HerdActivityState>(
      "a birth activity emits [Loading, Success('Birth recorded successfully')]",
      build: () {
        when(
          () => mockAddHerdActivity(any(), any(), any(), any(), any()),
        ).thenAnswer((_) async => Right(herdActivity()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AddHerdActivityEvent(
          herdId: 'herd-1',
          activityType: 'birth',
          count: 2,
          date: now,
        ),
      ),
      expect: () => [
        isA<HerdActivityLoading>(),
        const HerdActivitySuccess('Birth recorded successfully'),
      ],
      verify: (_) {
        verify(
          () => mockAddHerdActivity('herd-1', 'birth', 2, now, null),
        ).called(1);
      },
    );

    blocTest<HerdActivityBloc, HerdActivityState>(
      "a fatality activity emits [Loading, Success('Fatality recorded successfully')], "
      'passing notes straight through',
      build: () {
        when(
          () => mockAddHerdActivity(any(), any(), any(), any(), any()),
        ).thenAnswer(
          (_) async => Right(
            herdActivity(activityType: 'fatality', count: 1, notes: 'lion attack'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AddHerdActivityEvent(
          herdId: 'herd-1',
          activityType: 'fatality',
          count: 1,
          date: now,
          notes: 'lion attack',
        ),
      ),
      expect: () => [
        isA<HerdActivityLoading>(),
        const HerdActivitySuccess('Fatality recorded successfully'),
      ],
      verify: (_) {
        verify(
          () => mockAddHerdActivity(
            'herd-1',
            'fatality',
            1,
            now,
            'lion attack',
          ),
        ).called(1);
      },
    );

    blocTest<HerdActivityBloc, HerdActivityState>(
      'a NetworkFailure emits [Loading, Error] with the network message',
      build: () {
        when(
          () => mockAddHerdActivity(any(), any(), any(), any(), any()),
        ).thenAnswer((_) async => const Left(NetworkFailure()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AddHerdActivityEvent(
          herdId: 'herd-1',
          activityType: 'birth',
          count: 1,
          date: now,
        ),
      ),
      expect: () => [
        isA<HerdActivityLoading>(),
        const HerdActivityError(
          'No internet connection. Check your network and try again.',
        ),
      ],
    );

    blocTest<HerdActivityBloc, HerdActivityState>(
      'a ServerFailure with a message emits [Loading, Error] carrying that message',
      build: () {
        when(
          () => mockAddHerdActivity(any(), any(), any(), any(), any()),
        ).thenAnswer((_) async => const Left(ServerFailure('herd not found')));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AddHerdActivityEvent(
          herdId: 'herd-1',
          activityType: 'birth',
          count: 1,
          date: now,
        ),
      ),
      expect: () => [
        isA<HerdActivityLoading>(),
        const HerdActivityError('herd not found'),
      ],
    );

    blocTest<HerdActivityBloc, HerdActivityState>(
      'a ServerFailure with no message falls back to the generic failure message',
      build: () {
        when(
          () => mockAddHerdActivity(any(), any(), any(), any(), any()),
        ).thenAnswer((_) async => const Left(ServerFailure()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AddHerdActivityEvent(
          herdId: 'herd-1',
          activityType: 'birth',
          count: 1,
          date: now,
        ),
      ),
      expect: () => [
        isA<HerdActivityLoading>(),
        const HerdActivityError('Failed to record activity'),
      ],
    );
  });
}
