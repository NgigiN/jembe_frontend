import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHarvestRepository extends Mock implements HarvestRepository {}

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

  late MockHarvestRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(harvest());
  });

  setUp(() {
    mockRepository = MockHarvestRepository();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  HarvestBloc buildBloc() => HarvestBloc(repository: mockRepository);

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<HarvestBloc, HarvestState>(
      'GetHarvestsEvent emits [HarvestLoading, HarvestLoaded] from the '
      'repository',
      build: () {
        when(
          () => mockRepository.getHarvests(seasonId: any(named: 'seasonId')),
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
          () => mockRepository.addHarvest(any()),
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
          () => mockRepository.addHarvest(any()),
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
          () => mockRepository.watchHarvests(seasonId: any(named: 'seasonId')),
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
          () => mockRepository.watchHarvests(seasonId: 'season-1'),
        ).called(1);
      },
    );

    blocTest<HarvestBloc, HarvestState>(
      'dispatching WatchHarvestsEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchHarvests(seasonId: any(named: 'seasonId')),
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
          () => mockRepository.watchHarvests(seasonId: any(named: 'seasonId')),
        ).called(1);
      },
    );

    blocTest<HarvestBloc, HarvestState>(
      "AddHarvestEvent success emits successMessage 'Harvest recorded' "
      'using the stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addHarvest(any()),
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
          () => mockRepository.updateHarvest(any()),
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
          () => mockRepository.deleteHarvest(any()),
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
          () => mockRepository.addHarvest(any()),
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
          () => mockRepository.watchHarvests(seasonId: any(named: 'seasonId')),
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
          () => mockRepository.watchHarvests(seasonId: any(named: 'seasonId')),
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

  group('online infinite scroll (P3-02a, flag off)', () {
    blocTest<HarvestBloc, HarvestState>(
      'GetHarvestsEvent under a full page sets hasReachedMax true and derives '
      'nextCursor from the last id',
      build: () {
        when(
          () => mockRepository.getHarvests(
            seasonId: any(named: 'seasonId'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => Right([harvest(id: '3'), harvest(id: '2')]),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetHarvestsEvent()),
      expect: () => [
        const HarvestLoading(),
        HarvestLoaded(
          harvests: [harvest(id: '3'), harvest(id: '2')],
          nextCursor: 2,
        ),
      ],
    );

    blocTest<HarvestBloc, HarvestState>(
      'LoadMoreHarvestsEvent is a no-op when hasReachedMax (a ≤500-row '
      'account never issues a second fetch)',
      build: buildBloc,
      seed: () => HarvestLoaded(harvests: [harvest(id: '2')], nextCursor: 2),
      act: (bloc) => bloc.add(LoadMoreHarvestsEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => <HarvestState>[],
      verify: (_) {
        verifyNever(
          () => mockRepository.getHarvests(
            seasonId: any(named: 'seasonId'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        );
      },
    );

    blocTest<HarvestBloc, HarvestState>(
      'a full first page sets hasReachedMax false; LoadMore fetches with the '
      'cursor, APPENDS the next page and recomputes hasReachedMax/nextCursor',
      build: () {
        final page1 = List.generate(
          kOnlineListPageSize,
          (i) => harvest(id: '${1000 - i}'),
        );
        final page2 = [harvest(id: '500'), harvest(id: '499')];
        when(
          () => mockRepository.getHarvests(
            seasonId: any(named: 'seasonId'),
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
        bloc.add(GetHarvestsEvent());
        await bloc.stream.firstWhere((s) => s is HarvestLoaded);
        bloc.add(LoadMoreHarvestsEvent());
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const HarvestLoading(),
        isA<HarvestLoaded>()
            .having((s) => s.harvests.length, 'page 1 length',
                kOnlineListPageSize)
            .having((s) => s.hasReachedMax, 'hasReachedMax', false)
            .having((s) => s.nextCursor, 'nextCursor', 501),
        isA<HarvestLoaded>()
            .having((s) => s.harvests.length, 'appended length',
                kOnlineListPageSize + 2)
            .having((s) => s.hasReachedMax, 'hasReachedMax', true)
            .having((s) => s.nextCursor, 'nextCursor', 499),
      ],
      verify: (_) {
        verify(
          () => mockRepository.getHarvests(
            seasonId: any(named: 'seasonId'),
            limit: any(named: 'limit'),
            cursor: 501,
          ),
        ).called(1);
      },
    );
  });
}
