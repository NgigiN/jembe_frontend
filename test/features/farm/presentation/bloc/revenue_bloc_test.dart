import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRevenueRepository extends Mock implements RevenueRepository {}

void main() {
  final now = DateTime.now();
  Revenue revenue({
    String id = 'revenue-1',
    String source = 'plant',
    DateTime? date,
  }) => Revenue(
    id: id,
    userId: 'user-1',
    source: source,
    sourceId: 'server-season-1',
    type: 'Maize Harvest',
    quantity: 10,
    unitPrice: 50,
    total: 500,
    date: date ?? now,
    createdAt: now,
    updatedAt: now,
  );

  late MockRevenueRepository mockRepository;

  setUp(() {
    mockRepository = MockRevenueRepository();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  RevenueBloc buildBloc() => RevenueBloc(repository: mockRepository);

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<RevenueBloc, RevenueState>(
      'LoadRevenues emits [RevenueLoading, RevenueLoaded] from the '
      'repository',
      build: () {
        when(
          () => mockRepository.getRevenues(
            source: any(named: 'source'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => Right([revenue()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(LoadRevenues()),
      expect: () => [
        const RevenueLoading(),
        RevenueLoaded(revenues: [revenue()]),
      ],
    );

    blocTest<RevenueBloc, RevenueState>(
      "AddRevenueEvent success appends the returned revenue and emits "
      'RevenueAdded',
      build: () {
        when(
          () => mockRepository.addRevenue(
            source: any(named: 'source'),
            sourceId: any(named: 'sourceId'),
            type: any(named: 'type'),
            quantity: any(named: 'quantity'),
            unitPrice: any(named: 'unitPrice'),
            total: any(named: 'total'),
            date: any(named: 'date'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(revenue(id: 'revenue-2')));
        return buildBloc();
      },
      seed: () => RevenueLoaded(revenues: [revenue()]),
      act: (bloc) => bloc.add(
        AddRevenueEvent(
          source: 'plant',
          sourceId: 'server-season-1',
          type: 'Maize Harvest',
          quantity: 10,
          unitPrice: 50,
          date: now,
        ),
      ),
      expect: () => [
        isA<RevenueLoading>(),
        isA<RevenueAdded>()
            .having((s) => s.revenue.id, 'revenue.id', 'revenue-2')
            .having(
              (s) => s.revenues.map((r) => r.id),
              'revenues',
              ['revenue-1', 'revenue-2'],
            ),
      ],
    );
  });

  group('flag ON (reactive stream + distinct write states)', () {
    blocTest<RevenueBloc, RevenueState>(
      'WatchRevenuesEvent subscribes to repository.watchRevenues() and '
      'emits RevenueLoaded filtered by source',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchRevenues()).thenAnswer(
          (_) => Stream.value([
            revenue(id: 'r-plant', source: 'plant'),
            revenue(id: 'r-animal', source: 'animal'),
          ]),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchRevenuesEvent(source: 'plant')),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        RevenueLoaded(revenues: [revenue(id: 'r-plant', source: 'plant')]),
      ],
    );

    blocTest<RevenueBloc, RevenueState>(
      'dispatching WatchRevenuesEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchRevenues(),
        ).thenAnswer((_) => Stream.value([revenue()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchRevenuesEvent())
          ..add(WatchRevenuesEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        // If the guard didn't prevent a second subscribe, watchRevenues()
        // (the repository stream factory) would have been invoked twice.
        verify(() => mockRepository.watchRevenues()).called(1);
      },
    );

    blocTest<RevenueBloc, RevenueState>(
      'a filter change (source) on an already-live subscription re-emits '
      'from the cached list WITHOUT re-subscribing',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchRevenues()).thenAnswer(
          (_) => Stream.value([
            revenue(id: 'r-plant', source: 'plant'),
            revenue(id: 'r-animal', source: 'animal'),
          ]),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(WatchRevenuesEvent(source: 'plant'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(WatchRevenuesEvent(source: 'animal'));
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        RevenueLoaded(revenues: [revenue(id: 'r-plant', source: 'plant')]),
        RevenueLoaded(revenues: [revenue(id: 'r-animal', source: 'animal')]),
      ],
      verify: (_) {
        verify(() => mockRepository.watchRevenues()).called(1);
      },
    );

    blocTest<RevenueBloc, RevenueState>(
      'AddRevenueEvent (flag on) emits RevenueAdded carrying the '
      'offline-built revenue and the UNCHANGED current revenues (no manual '
      'append — the watch stream refreshes the list)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addRevenue(
            source: any(named: 'source'),
            sourceId: any(named: 'sourceId'),
            type: any(named: 'type'),
            quantity: any(named: 'quantity'),
            unitPrice: any(named: 'unitPrice'),
            total: any(named: 'total'),
            date: any(named: 'date'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(revenue(id: 'revenue-2')));
        return buildBloc();
      },
      seed: () => RevenueLoaded(revenues: [revenue()]),
      act: (bloc) => bloc.add(
        AddRevenueEvent(
          source: 'plant',
          sourceId: 'server-season-1',
          type: 'Maize Harvest',
          quantity: 10,
          unitPrice: 50,
          date: now,
        ),
      ),
      expect: () => [
        isA<RevenueAdded>()
            .having((s) => s.revenue.id, 'revenue.id', 'revenue-2')
            .having((s) => s.revenues, 'revenues (untouched)', [revenue()]),
      ],
    );

    blocTest<RevenueBloc, RevenueState>(
      'UpdateRevenueEvent (flag on) emits RevenueUpdated without manually '
      'replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.updateRevenue(
            id: any(named: 'id'),
            source: any(named: 'source'),
            sourceId: any(named: 'sourceId'),
            type: any(named: 'type'),
            quantity: any(named: 'quantity'),
            unitPrice: any(named: 'unitPrice'),
            total: any(named: 'total'),
            date: any(named: 'date'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(revenue()));
        return buildBloc();
      },
      seed: () => RevenueLoaded(revenues: [revenue()]),
      act: (bloc) => bloc.add(
        UpdateRevenueEvent(
          id: 'revenue-1',
          source: 'plant',
          sourceId: 'server-season-1',
          type: 'Maize Harvest',
          quantity: 10,
          unitPrice: 50,
          total: 500,
          date: now,
        ),
      ),
      expect: () => [
        isA<RevenueUpdated>()
            .having((s) => s.revenue.id, 'revenue.id', 'revenue-1')
            .having((s) => s.revenues, 'revenues (untouched)', [revenue()]),
      ],
    );

    blocTest<RevenueBloc, RevenueState>(
      'DeleteRevenueEvent (flag on) emits RevenueDeleted without manually '
      'removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.deleteRevenue(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => RevenueLoaded(revenues: [revenue()]),
      act: (bloc) => bloc.add(DeleteRevenueEvent('revenue-1')),
      expect: () => [
        RevenueDeleted(revenues: [revenue()]),
      ],
    );

    blocTest<RevenueBloc, RevenueState>(
      'AddRevenueEvent failure emits RevenueError preserving current '
      'revenues',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addRevenue(
            source: any(named: 'source'),
            sourceId: any(named: 'sourceId'),
            type: any(named: 'type'),
            quantity: any(named: 'quantity'),
            unitPrice: any(named: 'unitPrice'),
            total: any(named: 'total'),
            date: any(named: 'date'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => RevenueLoaded(revenues: [revenue()]),
      act: (bloc) => bloc.add(
        AddRevenueEvent(
          source: 'plant',
          sourceId: 'server-season-1',
          type: 'Maize Harvest',
          quantity: 10,
          unitPrice: 50,
          date: now,
        ),
      ),
      expect: () => [
        RevenueError('boom', revenues: [revenue()]),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Revenue>> controller;

    setUp(() {
      controller = StreamController<List<Revenue>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<RevenueBloc, RevenueState>(
      'a stream error emits a non-fatal RevenueError over the last known '
      '(filtered) revenues without crashing the bloc, and the subscription '
      'stays alive for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchRevenues())
            .thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => RevenueLoaded(revenues: [revenue()]),
      act: (bloc) async {
        bloc.add(WatchRevenuesEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([revenue(id: 'revenue-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        RevenueError(
          'Live sync interrupted. Pull to refresh.',
          revenues: [revenue()],
        ),
        RevenueLoaded(revenues: [revenue(id: 'revenue-2')]),
      ],
    );
  });

  group('online infinite scroll (P3-02a, flag off)', () {
    blocTest<RevenueBloc, RevenueState>(
      'LoadRevenues under a full page sets hasReachedMax true and derives '
      'nextCursor from the last id',
      build: () {
        when(
          () => mockRepository.getRevenues(
            source: any(named: 'source'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => Right([revenue(id: '3'), revenue(id: '2')]),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(LoadRevenues()),
      expect: () => [
        const RevenueLoading(),
        RevenueLoaded(
          revenues: [revenue(id: '3'), revenue(id: '2')],
          nextCursor: 2,
        ),
      ],
    );

    blocTest<RevenueBloc, RevenueState>(
      'LoadMoreRevenuesEvent is a no-op when hasReachedMax (a ≤500-row '
      'account never issues a second fetch)',
      build: buildBloc,
      seed: () => RevenueLoaded(revenues: [revenue(id: '2')], nextCursor: 2),
      act: (bloc) => bloc.add(LoadMoreRevenuesEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => <RevenueState>[],
      verify: (_) {
        verifyNever(
          () => mockRepository.getRevenues(
            source: any(named: 'source'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        );
      },
    );

    blocTest<RevenueBloc, RevenueState>(
      'a full first page sets hasReachedMax false; LoadMore fetches with the '
      'cursor, APPENDS the next page and recomputes hasReachedMax/nextCursor',
      build: () {
        final page1 = List.generate(
          kOnlineListPageSize,
          (i) => revenue(id: '${1000 - i}'),
        );
        final page2 = [revenue(id: '500'), revenue(id: '499')];
        when(
          () => mockRepository.getRevenues(
            source: any(named: 'source'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
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
        bloc.add(LoadRevenues());
        await bloc.stream.firstWhere((s) => s is RevenueLoaded);
        bloc.add(LoadMoreRevenuesEvent());
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const RevenueLoading(),
        isA<RevenueLoaded>()
            .having((s) => s.revenues.length, 'page 1 length',
                kOnlineListPageSize)
            .having((s) => s.hasReachedMax, 'hasReachedMax', false)
            .having((s) => s.nextCursor, 'nextCursor', 501),
        isA<RevenueLoaded>()
            .having((s) => s.revenues.length, 'appended length',
                kOnlineListPageSize + 2)
            .having((s) => s.hasReachedMax, 'hasReachedMax', true)
            .having((s) => s.nextCursor, 'nextCursor', 499),
      ],
      verify: (_) {
        verify(
          () => mockRepository.getRevenues(
            source: any(named: 'source'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            limit: any(named: 'limit'),
            cursor: 501,
          ),
        ).called(1);
      },
    );
  });
}
