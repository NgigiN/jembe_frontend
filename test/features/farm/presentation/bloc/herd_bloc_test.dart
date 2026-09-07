import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHerdRepository extends Mock implements HerdRepository {}

void main() {
  final now = DateTime.now();
  Herd herd({String id = 'herd-1', String name = 'North Herd'}) => Herd(
    id: id,
    userId: 'user-1',
    name: name,
    animalTypeId: 'type-1',
    location: 'North Field',
    initialHeadCount: 10,
    currentHeadCount: 10,
    startDate: now,
    createdAt: now,
    updatedAt: now,
  );

  late MockHerdRepository mockRepository;

  setUp(() {
    mockRepository = MockHerdRepository();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  HerdBloc buildBloc() => HerdBloc(repository: mockRepository);

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<HerdBloc, HerdState>(
      'GetHerdsEvent emits [HerdLoading, HerdLoaded] from the repository',
      build: () {
        when(() => mockRepository.getHerds())
            .thenAnswer((_) async => Right([herd()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetHerdsEvent()),
      expect: () => [
        const HerdLoading(),
        HerdLoaded([herd()]),
      ],
    );

    blocTest<HerdBloc, HerdState>(
      "AddHerdEvent success appends the returned herd and sets "
      "successMessage 'Herd created'",
      build: () {
        when(
          () => mockRepository.addHerd(
            any(),
            any(),
            any(),
            any(),
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => Right(herd(id: 'herd-2')));
        return buildBloc();
      },
      seed: () => HerdLoaded([herd()]),
      act: (bloc) => bloc.add(
        AddHerdEvent(
          'North Herd',
          'type-1',
          'North Field',
          'user-1',
          10,
          startDate: now,
        ),
      ),
      expect: () => [
        isA<HerdLoading>(),
        HerdLoaded(
          [herd(), herd(id: 'herd-2')],
          successMessage: 'Herd created',
        ),
      ],
    );

    blocTest<HerdBloc, HerdState>(
      'AddHerdEvent failure emits HerdError preserving current herds',
      build: () {
        when(
          () => mockRepository.addHerd(
            any(),
            any(),
            any(),
            any(),
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => HerdLoaded([herd()]),
      act: (bloc) => bloc.add(
        AddHerdEvent(
          'North Herd',
          'type-1',
          'North Field',
          'user-1',
          10,
          startDate: now,
        ),
      ),
      expect: () => [
        isA<HerdLoading>(),
        HerdError('boom', herds: [herd()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<HerdBloc, HerdState>(
      'WatchHerdsEvent subscribes to repository.watchHerds() and emits '
      'HerdLoaded per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchHerds())
            .thenAnswer((_) => Stream.value([herd()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchHerdsEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        HerdLoaded([herd()]),
      ],
    );

    blocTest<HerdBloc, HerdState>(
      'dispatching WatchHerdsEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchHerds())
            .thenAnswer((_) => Stream.value([herd()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchHerdsEvent())
          ..add(WatchHerdsEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(() => mockRepository.watchHerds()).called(1);
      },
    );

    blocTest<HerdBloc, HerdState>(
      "AddHerdEvent success emits successMessage 'Herd created' using the "
      'stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addHerd(
            any(),
            any(),
            any(),
            any(),
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => Right(herd(id: 'herd-2')));
        return buildBloc();
      },
      seed: () => HerdLoaded([herd()]),
      act: (bloc) => bloc.add(
        AddHerdEvent(
          'North Herd',
          'type-1',
          'North Field',
          'user-1',
          10,
          startDate: now,
        ),
      ),
      expect: () => [
        HerdLoaded([herd()], successMessage: 'Herd created'),
      ],
    );

    blocTest<HerdBloc, HerdState>(
      "UpdateHerdEvent success emits successMessage 'Herd updated' without "
      'manually replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.updateHerd(
            any(),
            any(),
            any(),
            any(),
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => Right(herd(name: 'Renamed')));
        return buildBloc();
      },
      seed: () => HerdLoaded([herd()]),
      act: (bloc) => bloc.add(
        UpdateHerdEvent(
          'herd-1',
          'Renamed',
          'type-1',
          'North Field',
          10,
          startDate: now,
        ),
      ),
      expect: () => [
        HerdLoaded([herd()], successMessage: 'Herd updated'),
      ],
    );

    blocTest<HerdBloc, HerdState>(
      "DeleteHerdEvent success emits successMessage 'Herd deleted' without "
      'manually removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.deleteHerd(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => HerdLoaded([herd()]),
      act: (bloc) => bloc.add(const DeleteHerdEvent('herd-1')),
      expect: () => [
        HerdLoaded([herd()], successMessage: 'Herd deleted'),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Herd>> controller;

    setUp(() {
      controller = StreamController<List<Herd>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<HerdBloc, HerdState>(
      'a stream error emits a non-fatal HerdError over the last known '
      'herds without crashing the bloc, and the subscription stays alive '
      'for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchHerds())
            .thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => HerdLoaded([herd()]),
      act: (bloc) async {
        bloc.add(WatchHerdsEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([herd(id: 'herd-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        HerdError('Live sync interrupted. Pull to refresh.', herds: [herd()]),
        HerdLoaded([herd(id: 'herd-2')]),
      ],
    );
  });
}
