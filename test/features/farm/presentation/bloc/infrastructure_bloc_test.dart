import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInfrastructureRepository extends Mock
    implements InfrastructureRepository {}

void main() {
  final now = DateTime.now();
  Infrastructure infrastructure({String id = 'infra-1', String name = 'Main Barn'}) =>
      Infrastructure(
        id: id,
        userId: 'user-1',
        type: 'Barn',
        name: name,
        location: 'North Field',
        cost: 1000,
        date: now,
        notes: '',
        createdAt: now,
        updatedAt: now,
      );

  late MockInfrastructureRepository mockRepository;

  setUp(() {
    mockRepository = MockInfrastructureRepository();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  InfrastructureBloc buildBloc() =>
      InfrastructureBloc(repository: mockRepository);

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<InfrastructureBloc, InfrastructureState>(
      'GetInfrastructuresEvent emits [InfrastructureLoading, '
      'InfrastructureLoaded] from the repository',
      build: () {
        when(
          () => mockRepository.getInfrastructures(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Right([infrastructure()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetInfrastructuresEvent()),
      expect: () => [
        const InfrastructureLoading(),
        InfrastructureLoaded([infrastructure()]),
      ],
    );

    blocTest<InfrastructureBloc, InfrastructureState>(
      "AddInfrastructureEvent success appends the returned item and sets "
      "successMessage 'Infrastructure added'",
      build: () {
        when(
          () => mockRepository.addInfrastructure(
            any(), any(), any(), any(), any(), any(), any()),
        ).thenAnswer((_) async => Right(infrastructure(id: 'infra-2')));
        return buildBloc();
      },
      seed: () => InfrastructureLoaded([infrastructure()]),
      act: (bloc) => bloc.add(
        AddInfrastructureEvent(
          type: 'Barn',
          name: 'Main Barn',
          location: 'North Field',
          cost: 1000,
          date: now,
          userId: 'user-1',
        ),
      ),
      expect: () => [
        isA<InfrastructureLoading>(),
        InfrastructureLoaded(
          [infrastructure(), infrastructure(id: 'infra-2')],
          successMessage: 'Infrastructure added',
        ),
      ],
    );

    blocTest<InfrastructureBloc, InfrastructureState>(
      'AddInfrastructureEvent failure emits InfrastructureError preserving '
      'current infrastructures',
      build: () {
        when(
          () => mockRepository.addInfrastructure(
            any(), any(), any(), any(), any(), any(), any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => InfrastructureLoaded([infrastructure()]),
      act: (bloc) => bloc.add(
        AddInfrastructureEvent(
          type: 'Barn',
          name: 'Main Barn',
          location: 'North Field',
          cost: 1000,
          date: now,
          userId: 'user-1',
        ),
      ),
      expect: () => [
        isA<InfrastructureLoading>(),
        InfrastructureError('boom', infrastructures: [infrastructure()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<InfrastructureBloc, InfrastructureState>(
      'WatchInfrastructureEvent subscribes to '
      'repository.watchInfrastructures() and emits InfrastructureLoaded '
      'per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchInfrastructures(),
        ).thenAnswer((_) => Stream.value([infrastructure()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchInfrastructureEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        InfrastructureLoaded([infrastructure()]),
      ],
    );

    blocTest<InfrastructureBloc, InfrastructureState>(
      'dispatching WatchInfrastructureEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchInfrastructures(),
        ).thenAnswer((_) => Stream.value([infrastructure()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchInfrastructureEvent())
          ..add(WatchInfrastructureEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(() => mockRepository.watchInfrastructures()).called(1);
      },
    );

    blocTest<InfrastructureBloc, InfrastructureState>(
      "AddInfrastructureEvent success emits successMessage 'Infrastructure "
      "added' using the stream-driven list — NOT a manual append",
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addInfrastructure(
            any(), any(), any(), any(), any(), any(), any()),
        ).thenAnswer((_) async => Right(infrastructure(id: 'infra-2')));
        return buildBloc();
      },
      seed: () => InfrastructureLoaded([infrastructure()]),
      act: (bloc) => bloc.add(
        AddInfrastructureEvent(
          type: 'Barn',
          name: 'Main Barn',
          location: 'North Field',
          cost: 1000,
          date: now,
          userId: 'user-1',
        ),
      ),
      expect: () => [
        InfrastructureLoaded(
          [infrastructure()],
          successMessage: 'Infrastructure added',
        ),
      ],
    );

    blocTest<InfrastructureBloc, InfrastructureState>(
      "UpdateInfrastructureEvent success emits successMessage "
      "'Infrastructure updated' without manually replacing the list",
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.updateInfrastructure(
            any(), any(), any(), any(), any(), any(), any()),
        ).thenAnswer((_) async => Right(infrastructure(name: 'Renamed')));
        return buildBloc();
      },
      seed: () => InfrastructureLoaded([infrastructure()]),
      act: (bloc) => bloc.add(
        UpdateInfrastructureEvent(
          id: 'infra-1',
          type: 'Barn',
          name: 'Renamed',
          location: 'North Field',
          cost: 1000,
          date: now,
        ),
      ),
      expect: () => [
        InfrastructureLoaded(
          [infrastructure()],
          successMessage: 'Infrastructure updated',
        ),
      ],
    );

    blocTest<InfrastructureBloc, InfrastructureState>(
      "DeleteInfrastructureEvent success emits successMessage "
      "'Infrastructure deleted' without manually removing from the list",
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.deleteInfrastructure(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => InfrastructureLoaded([infrastructure()]),
      act: (bloc) => bloc.add(const DeleteInfrastructureEvent('infra-1')),
      expect: () => [
        InfrastructureLoaded(
          [infrastructure()],
          successMessage: 'Infrastructure deleted',
        ),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Infrastructure>> controller;

    setUp(() {
      controller = StreamController<List<Infrastructure>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<InfrastructureBloc, InfrastructureState>(
      'a stream error emits a non-fatal InfrastructureError over the last '
      'known infrastructures without crashing the bloc, and the '
      'subscription stays alive for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchInfrastructures(),
        ).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => InfrastructureLoaded([infrastructure()]),
      act: (bloc) async {
        bloc.add(WatchInfrastructureEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([infrastructure(id: 'infra-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        InfrastructureError(
          'Live sync interrupted. Pull to refresh.',
          infrastructures: [infrastructure()],
        ),
        InfrastructureLoaded([infrastructure(id: 'infra-2')]),
      ],
    );
  });

  group('online infinite scroll (P3-02a, flag off)', () {
    blocTest<InfrastructureBloc, InfrastructureState>(
      'GetInfrastructuresEvent under a full page sets hasReachedMax true '
      'and derives nextCursor from the last id',
      build: () {
        when(
          () => mockRepository.getInfrastructures(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async =>
              Right([infrastructure(id: '3'), infrastructure(id: '2')]),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetInfrastructuresEvent()),
      expect: () => [
        const InfrastructureLoading(),
        InfrastructureLoaded(
          [infrastructure(id: '3'), infrastructure(id: '2')],
          nextCursor: 2,
        ),
      ],
    );

    blocTest<InfrastructureBloc, InfrastructureState>(
      'LoadMoreInfrastructuresEvent is a no-op when hasReachedMax (a '
      '≤500-row account never issues a second fetch)',
      build: buildBloc,
      seed: () =>
          InfrastructureLoaded([infrastructure(id: '2')], nextCursor: 2),
      act: (bloc) => bloc.add(LoadMoreInfrastructuresEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => <InfrastructureState>[],
      verify: (_) {
        verifyNever(
          () => mockRepository.getInfrastructures(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        );
      },
    );

    blocTest<InfrastructureBloc, InfrastructureState>(
      'a full first page sets hasReachedMax false; LoadMore fetches with '
      'the cursor, APPENDS the next page and recomputes '
      'hasReachedMax/nextCursor',
      build: () {
        final page1 = List.generate(
          kOnlineListPageSize,
          (i) => infrastructure(id: '${1000 - i}'),
        );
        final page2 = [infrastructure(id: '500'), infrastructure(id: '499')];
        when(
          () => mockRepository.getInfrastructures(
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
        bloc.add(GetInfrastructuresEvent());
        await bloc.stream.firstWhere((s) => s is InfrastructureLoaded);
        bloc.add(LoadMoreInfrastructuresEvent());
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const InfrastructureLoading(),
        isA<InfrastructureLoaded>()
            .having((s) => s.infrastructures.length, 'page 1 length',
                kOnlineListPageSize)
            .having((s) => s.hasReachedMax, 'hasReachedMax', false)
            .having((s) => s.nextCursor, 'nextCursor', 501),
        isA<InfrastructureLoaded>()
            .having((s) => s.infrastructures.length, 'appended length',
                kOnlineListPageSize + 2)
            .having((s) => s.hasReachedMax, 'hasReachedMax', true)
            .having((s) => s.nextCursor, 'nextCursor', 499),
      ],
      verify: (_) {
        verify(
          () => mockRepository.getInfrastructures(
            limit: any(named: 'limit'),
            cursor: 501,
          ),
        ).called(1);
      },
    );
  });
}
