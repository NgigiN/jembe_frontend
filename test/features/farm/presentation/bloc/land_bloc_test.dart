import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLandRepository extends Mock implements LandRepository {}

void main() {
  final now = DateTime.now();
  Land land({String id = 'land-1', String name = 'North Field'}) => Land(
    id: id,
    userId: 'user-1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );

  late MockLandRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(land());
  });

  setUp(() {
    mockRepository = MockLandRepository();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  LandBloc buildBloc() => LandBloc(repository: mockRepository);

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<LandBloc, LandState>(
      'GetLandsEvent emits [LandLoading, LandLoaded] from the repository',
      build: () {
        when(
          () => mockRepository.getLands(),
        ).thenAnswer((_) async => Right([land()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetLandsEvent()),
      expect: () => [
        const LandLoading(),
        LandLoaded(lands: [land()]),
      ],
    );

    blocTest<LandBloc, LandState>(
      'AddLandEvent success appends the returned land, sets successMessage '
      "'Land added', and surfaces its (server) id via addedLandId",
      build: () {
        when(
          () => mockRepository.addLand(any()),
        ).thenAnswer((_) async => Right(land(id: 'land-2')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(AddLandEvent(land(id: 'land-2'))),
      expect: () => [
        isA<LandLoading>(),
        LandLoaded(
          lands: [
            land(),
            land(id: 'land-2'),
          ],
          successMessage: 'Land added',
          addedLandId: 'land-2',
        ),
      ],
    );

    blocTest<LandBloc, LandState>(
      'AddLandEvent failure emits LandError preserving current lands',
      build: () {
        when(
          () => mockRepository.addLand(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(AddLandEvent(land(id: 'land-2'))),
      expect: () => [
        isA<LandLoading>(),
        LandError('boom', lands: [land()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<LandBloc, LandState>(
      'WatchLandsEvent subscribes to repository.watchLands() and emits '
      'LandLoaded per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchLands())
            .thenAnswer((_) => Stream.value([land()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchLandsEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        LandLoaded(lands: [land()]),
      ],
    );

    blocTest<LandBloc, LandState>(
      'dispatching WatchLandsEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchLands())
            .thenAnswer((_) => Stream.value([land()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchLandsEvent())
          ..add(WatchLandsEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        // If the guard didn't prevent a second subscribe, watchLands()
        // (the repository stream factory) would have been invoked twice.
        verify(() => mockRepository.watchLands()).called(1);
      },
    );

    blocTest<LandBloc, LandState>(
      "AddLandEvent success emits successMessage 'Land added' using the "
      'stream-driven list — NOT a manual append — while still threading '
      'the created clientUuid through addedLandId',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        // The repository "succeeds" with a different land than what's already
        // in state, to prove the emitted list is untouched by the result
        // (i.e. no manual append) — only a real stream emission would add
        // it, and this test deliberately never seeds one.
        when(
          () => mockRepository.addLand(any()),
        ).thenAnswer((_) async => Right(land(id: 'land-2')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(AddLandEvent(land(id: 'land-2'))),
      expect: () => [
        LandLoaded(
          lands: [land()],
          successMessage: 'Land added',
          addedLandId: 'land-2',
        ),
      ],
    );

    blocTest<LandBloc, LandState>(
      "AddLandEvent success carries the repo's returned clientUuid via "
      'addedLandId, not the (stale, pre-write) lands list or its last '
      'element — the regression this guards against: showAddLandDialog '
      'used to read `s.lands.last.id`, which is null/wrong here because '
      "the list in this state is the OLD snapshot ('land-1' only)",
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addLand(any()),
        ).thenAnswer((_) async => Right(land(id: 'clientUuid-999')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(AddLandEvent(land(id: 'clientUuid-999'))),
      verify: (bloc) {
        final state = bloc.state;
        expect(state, isA<LandLoaded>());
        expect((state as LandLoaded).successMessage, 'Land added');
        expect(state.addedLandId, 'clientUuid-999');
        // The list itself is untouched — proving addedLandId (not list
        // position) is what showAddLandDialog must read.
        expect(state.lands.map((l) => l.id), ['land-1']);
      },
    );

    blocTest<LandBloc, LandState>(
      "UpdateLandEvent success emits successMessage 'Land updated' without "
      'manually replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.updateLand(any()),
        ).thenAnswer((_) async => Right(land(name: 'Renamed')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(UpdateLandEvent(land(name: 'Renamed'))),
      expect: () => [
        LandLoaded(lands: [land()], successMessage: 'Land updated'),
      ],
    );

    blocTest<LandBloc, LandState>(
      "DeleteLandEvent success emits successMessage 'Land deleted' without "
      'manually removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.deleteLand(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(DeleteLandEvent('land-1')),
      expect: () => [
        LandLoaded(lands: [land()], successMessage: 'Land deleted'),
      ],
    );

    blocTest<LandBloc, LandState>(
      'AddLandEvent failure emits LandError preserving current lands',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addLand(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(AddLandEvent(land(id: 'land-2'))),
      expect: () => [
        LandError('boom', lands: [land()]),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Land>> controller;

    setUp(() {
      controller = StreamController<List<Land>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<LandBloc, LandState>(
      'a stream error emits a non-fatal LandError over the last known '
      'lands without crashing the bloc, and the subscription stays alive '
      'for a later emission (proving it was not torn down by the error)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchLands())
            .thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) async {
        bloc.add(WatchLandsEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([land(id: 'land-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        LandError('Live sync interrupted. Pull to refresh.', lands: [land()]),
        LandLoaded(lands: [land(id: 'land-2')]),
      ],
    );

    blocTest<LandBloc, LandState>(
      'a completed stream (onDone) does not emit any state or crash the '
      'bloc',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchLands())
            .thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) async {
        bloc.add(WatchLandsEvent());
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      wait: const Duration(milliseconds: 50),
      expect: () => <LandState>[],
    );
  });
}
