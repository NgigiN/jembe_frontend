import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_harvests.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_harvests.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetHarvests extends Mock implements GetHarvests {}

class MockAddHarvest extends Mock implements AddHarvest {}

class MockUpdateHarvest extends Mock implements UpdateHarvest {}

class MockDeleteHarvest extends Mock implements DeleteHarvest {}

class MockWatchHarvests extends Mock implements WatchHarvests {}

void main() {
  final now = DateTime.now();
  Harvest harvest({String id = 'harvest-1', double quantity = 10}) => Harvest(
    id: id,
    seasonId: 'season-1',
    quantity: quantity,
    unit: 'kg',
    date: now,
    createdAt: now,
    updatedAt: now,
  );

  late MockGetHarvests mockGetHarvests;
  late MockAddHarvest mockAddHarvest;
  late MockUpdateHarvest mockUpdateHarvest;
  late MockDeleteHarvest mockDeleteHarvest;
  late MockWatchHarvests mockWatchHarvests;

  setUpAll(() {
    registerFallbackValue(const GetHarvestsParams());
    registerFallbackValue(AddHarvestParams(harvest: harvest()));
    registerFallbackValue(UpdateHarvestParams(harvest: harvest()));
    registerFallbackValue(DeleteHarvestParams(id: 'harvest-1'));
  });

  setUp(() {
    mockGetHarvests = MockGetHarvests();
    mockAddHarvest = MockAddHarvest();
    mockUpdateHarvest = MockUpdateHarvest();
    mockDeleteHarvest = MockDeleteHarvest();
    mockWatchHarvests = MockWatchHarvests();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  HarvestBloc buildBloc() => HarvestBloc(
    getHarvests: mockGetHarvests,
    addHarvest: mockAddHarvest,
    updateHarvest: mockUpdateHarvest,
    deleteHarvest: mockDeleteHarvest,
    watchHarvests: mockWatchHarvests,
  );

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<HarvestBloc, HarvestState>(
      'GetHarvestsEvent emits [HarvestLoading, HarvestLoaded] from the use '
      'case',
      build: () {
        when(
          () => mockGetHarvests(any()),
        ).thenAnswer((_) async => Right([harvest()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetHarvestsEvent()),
      expect: () => [
        const HarvestLoading(),
        HarvestLoaded(harvests: [harvest()]),
      ],
    );

    blocTest<HarvestBloc, HarvestState>(
      "AddHarvestEvent success appends the returned harvest and sets "
      "successMessage 'Harvest recorded'",
      build: () {
        when(
          () => mockAddHarvest(any()),
        ).thenAnswer((_) async => Right(harvest(id: 'harvest-2')));
        return buildBloc();
      },
      seed: () => HarvestLoaded(harvests: [harvest()]),
      act: (bloc) => bloc.add(AddHarvestEvent(harvest(id: 'harvest-2'))),
      expect: () => [
        isA<HarvestLoading>(),
        HarvestLoaded(
          harvests: [harvest(), harvest(id: 'harvest-2')],
          successMessage: 'Harvest recorded',
        ),
      ],
    );

    blocTest<HarvestBloc, HarvestState>(
      'AddHarvestEvent failure emits HarvestError preserving current '
      'harvests',
      build: () {
        when(
          () => mockAddHarvest(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => HarvestLoaded(harvests: [harvest()]),
      act: (bloc) => bloc.add(AddHarvestEvent(harvest(id: 'harvest-2'))),
      expect: () => [
        isA<HarvestLoading>(),
        HarvestError('boom', harvests: [harvest()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<HarvestBloc, HarvestState>(
      'WatchHarvestsEvent subscribes to repository.watchHarvests(seasonId:) '
      'and emits HarvestLoaded per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchHarvests(seasonId: any(named: 'seasonId')),
        ).thenAnswer((_) => Stream.value([harvest()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchHarvestsEvent(seasonId: 'season-1')),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        HarvestLoaded(harvests: [harvest()]),
      ],
      verify: (_) {
        verify(
          () => mockWatchHarvests(seasonId: 'season-1'),
        ).called(1);
      },
    );

    blocTest<HarvestBloc, HarvestState>(
      'dispatching WatchHarvestsEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchHarvests(seasonId: any(named: 'seasonId')),
        ).thenAnswer((_) => Stream.value([harvest()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchHarvestsEvent())
          ..add(WatchHarvestsEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(
          () => mockWatchHarvests(seasonId: any(named: 'seasonId')),
        ).called(1);
      },
    );

    blocTest<HarvestBloc, HarvestState>(
      "AddHarvestEvent success emits successMessage 'Harvest recorded' "
      'using the stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddHarvest(any()),
        ).thenAnswer((_) async => Right(harvest(id: 'harvest-2')));
        return buildBloc();
      },
      seed: () => HarvestLoaded(harvests: [harvest()]),
      act: (bloc) => bloc.add(AddHarvestEvent(harvest(id: 'harvest-2'))),
      expect: () => [
        HarvestLoaded(
          harvests: [harvest()],
          successMessage: 'Harvest recorded',
        ),
      ],
    );

    blocTest<HarvestBloc, HarvestState>(
      "UpdateHarvestEvent success emits successMessage 'Harvest updated' "
      'without manually replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockUpdateHarvest(any()),
        ).thenAnswer((_) async => Right(harvest(quantity: 99)));
        return buildBloc();
      },
      seed: () => HarvestLoaded(harvests: [harvest()]),
      act: (bloc) => bloc.add(UpdateHarvestEvent(harvest(quantity: 99))),
      expect: () => [
        HarvestLoaded(harvests: [harvest()], successMessage: 'Harvest updated'),
      ],
    );

    blocTest<HarvestBloc, HarvestState>(
      "DeleteHarvestEvent success emits successMessage 'Harvest deleted' "
      'without manually removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockDeleteHarvest(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => HarvestLoaded(harvests: [harvest()]),
      act: (bloc) => bloc.add(DeleteHarvestEvent('harvest-1')),
      expect: () => [
        HarvestLoaded(harvests: [harvest()], successMessage: 'Harvest deleted'),
      ],
    );

    blocTest<HarvestBloc, HarvestState>(
      'AddHarvestEvent failure emits HarvestError preserving current '
      'harvests',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddHarvest(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => HarvestLoaded(harvests: [harvest()]),
      act: (bloc) => bloc.add(AddHarvestEvent(harvest(id: 'harvest-2'))),
      expect: () => [
        HarvestError('boom', harvests: [harvest()]),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Harvest>> controller;

    setUp(() {
      controller = StreamController<List<Harvest>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<HarvestBloc, HarvestState>(
      'a stream error emits a non-fatal HarvestError over the last known '
      'harvests without crashing the bloc, and the subscription stays '
      'alive for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchHarvests(seasonId: any(named: 'seasonId')),
        ).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => HarvestLoaded(harvests: [harvest()]),
      act: (bloc) async {
        bloc.add(WatchHarvestsEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([harvest(id: 'harvest-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        HarvestError(
          'Live sync interrupted. Pull to refresh.',
          harvests: [harvest()],
        ),
        HarvestLoaded(harvests: [harvest(id: 'harvest-2')]),
      ],
    );

    blocTest<HarvestBloc, HarvestState>(
      'a completed stream (onDone) does not emit any state or crash the '
      'bloc',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchHarvests(seasonId: any(named: 'seasonId')),
        ).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => HarvestLoaded(harvests: [harvest()]),
      act: (bloc) async {
        bloc.add(WatchHarvestsEvent());
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      wait: const Duration(milliseconds: 50),
      expect: () => <HarvestState>[],
    );
  });
}
