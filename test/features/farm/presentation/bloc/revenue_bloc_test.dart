import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_revenue_by_id.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_revenues.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_revenues_params.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_revenues.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetRevenues extends Mock implements GetRevenues {}

class MockGetRevenueById extends Mock implements GetRevenueById {}

class MockAddRevenue extends Mock implements AddRevenue {}

class MockUpdateRevenue extends Mock implements UpdateRevenue {}

class MockDeleteRevenue extends Mock implements DeleteRevenue {}

class MockWatchRevenues extends Mock implements WatchRevenues {}

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

  late MockGetRevenues mockGetRevenues;
  late MockGetRevenueById mockGetRevenueById;
  late MockAddRevenue mockAddRevenue;
  late MockUpdateRevenue mockUpdateRevenue;
  late MockDeleteRevenue mockDeleteRevenue;
  late MockWatchRevenues mockWatchRevenues;

  setUpAll(() {
    registerFallbackValue(const GetRevenuesParams());
    registerFallbackValue(
      AddRevenueParams(
        source: 'plant',
        sourceId: 'server-season-1',
        type: 'X',
        quantity: 1,
        unitPrice: 1,
        date: now,
      ),
    );
    registerFallbackValue(
      UpdateRevenueParams(
        id: 'revenue-1',
        source: 'plant',
        sourceId: 'server-season-1',
        type: 'X',
        quantity: 1,
        unitPrice: 1,
        total: 1,
        date: now,
      ),
    );
  });

  setUp(() {
    mockGetRevenues = MockGetRevenues();
    mockGetRevenueById = MockGetRevenueById();
    mockAddRevenue = MockAddRevenue();
    mockUpdateRevenue = MockUpdateRevenue();
    mockDeleteRevenue = MockDeleteRevenue();
    mockWatchRevenues = MockWatchRevenues();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  RevenueBloc buildBloc() => RevenueBloc(
    getRevenues: mockGetRevenues,
    getRevenueById: mockGetRevenueById,
    addRevenue: mockAddRevenue,
    updateRevenue: mockUpdateRevenue,
    deleteRevenue: mockDeleteRevenue,
    watchRevenues: mockWatchRevenues,
  );

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<RevenueBloc, RevenueState>(
      'LoadRevenues emits [RevenueLoading, RevenueLoaded] from the use case',
      build: () {
        when(
          () => mockGetRevenues(any()),
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
          () => mockAddRevenue(any()),
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
        when(() => mockWatchRevenues()).thenAnswer(
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
          () => mockWatchRevenues(),
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
        verify(() => mockWatchRevenues()).called(1);
      },
    );

    blocTest<RevenueBloc, RevenueState>(
      'a filter change (source) on an already-live subscription re-emits '
      'from the cached list WITHOUT re-subscribing',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockWatchRevenues()).thenAnswer(
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
        verify(() => mockWatchRevenues()).called(1);
      },
    );

    blocTest<RevenueBloc, RevenueState>(
      'AddRevenueEvent (flag on) emits RevenueAdded carrying the '
      'offline-built revenue and the UNCHANGED current revenues (no manual '
      'append — the watch stream refreshes the list)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddRevenue(any()),
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
          () => mockUpdateRevenue(any()),
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
          () => mockDeleteRevenue(any()),
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
          () => mockAddRevenue(any()),
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
        when(() => mockWatchRevenues()).thenAnswer((_) => controller.stream);
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
}
