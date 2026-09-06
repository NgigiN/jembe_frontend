import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_infrastructure.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetInfrastructure extends Mock implements GetInfrastructure {}

class MockAddInfrastructure extends Mock implements AddInfrastructure {}

class MockUpdateInfrastructure extends Mock implements UpdateInfrastructure {}

class MockDeleteInfrastructure extends Mock implements DeleteInfrastructure {}

class MockWatchInfrastructure extends Mock implements WatchInfrastructure {}

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

  late MockGetInfrastructure mockGetInfrastructure;
  late MockAddInfrastructure mockAddInfrastructure;
  late MockUpdateInfrastructure mockUpdateInfrastructure;
  late MockDeleteInfrastructure mockDeleteInfrastructure;
  late MockWatchInfrastructure mockWatchInfrastructure;

  setUpAll(() {
    registerFallbackValue(NoParams());
  });

  setUp(() {
    mockGetInfrastructure = MockGetInfrastructure();
    mockAddInfrastructure = MockAddInfrastructure();
    mockUpdateInfrastructure = MockUpdateInfrastructure();
    mockDeleteInfrastructure = MockDeleteInfrastructure();
    mockWatchInfrastructure = MockWatchInfrastructure();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  InfrastructureBloc buildBloc() => InfrastructureBloc(
    getInfrastructure: mockGetInfrastructure,
    addInfrastructure: mockAddInfrastructure,
    updateInfrastructure: mockUpdateInfrastructure,
    deleteInfrastructure: mockDeleteInfrastructure,
    watchInfrastructure: mockWatchInfrastructure,
  );

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<InfrastructureBloc, InfrastructureState>(
      'GetInfrastructuresEvent emits [InfrastructureLoading, '
      'InfrastructureLoaded] from the use case',
      build: () {
        when(
          () => mockGetInfrastructure(any()),
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
          () => mockAddInfrastructure(any(), any(), any(), any(), any(), any(), any()),
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
          () => mockAddInfrastructure(any(), any(), any(), any(), any(), any(), any()),
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
          () => mockWatchInfrastructure(),
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
          () => mockWatchInfrastructure(),
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
        verify(() => mockWatchInfrastructure()).called(1);
      },
    );

    blocTest<InfrastructureBloc, InfrastructureState>(
      "AddInfrastructureEvent success emits successMessage 'Infrastructure "
      "added' using the stream-driven list — NOT a manual append",
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddInfrastructure(any(), any(), any(), any(), any(), any(), any()),
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
          () => mockUpdateInfrastructure(any(), any(), any(), any(), any(), any(), any()),
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
          () => mockDeleteInfrastructure(any()),
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
          () => mockWatchInfrastructure(),
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
}
