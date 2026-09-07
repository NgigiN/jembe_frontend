import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInputRepository extends Mock implements InputRepository {}

void main() {
  final now = DateTime.now();
  Input input({String id = 'input-1', double cost = 100}) => Input(
    id: id,
    sourceType: 'plant',
    sourceId: 'season-1',
    type: 'Fertilizer',
    cost: cost,
    date: now,
    createdAt: now,
    updatedAt: now,
  );

  late MockInputRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(input());
  });

  setUp(() {
    mockRepository = MockInputRepository();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  InputBloc buildBloc() => InputBloc(repository: mockRepository);

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<InputBloc, InputState>(
      'GetInputsEvent emits [InputLoading, InputLoaded] from the repository',
      build: () {
        when(
          () => mockRepository.getInputs(sourceType: any(named: 'sourceType')),
        ).thenAnswer((_) async => Right([input()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetInputsEvent()),
      expect: () => [
        const InputLoading(),
        InputLoaded(inputs: [input()]),
      ],
    );

    blocTest<InputBloc, InputState>(
      "AddInputEvent success appends the returned input and sets "
      "successMessage 'Input added'",
      build: () {
        when(
          () => mockRepository.addInput(any()),
        ).thenAnswer((_) async => Right(input(id: 'input-2')));
        return buildBloc();
      },
      seed: () => InputLoaded(inputs: [input()]),
      act: (bloc) => bloc.add(AddInputEvent(input(id: 'input-2'))),
      expect: () => [
        isA<InputLoading>(),
        InputLoaded(
          inputs: [input(), input(id: 'input-2')],
          successMessage: 'Input added',
        ),
      ],
    );

    blocTest<InputBloc, InputState>(
      'AddInputEvent failure emits InputError preserving current inputs',
      build: () {
        when(
          () => mockRepository.addInput(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => InputLoaded(inputs: [input()]),
      act: (bloc) => bloc.add(AddInputEvent(input(id: 'input-2'))),
      expect: () => [
        isA<InputLoading>(),
        InputError('boom', inputs: [input()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<InputBloc, InputState>(
      'WatchInputsEvent subscribes to repository.watchInputs(sourceType:) '
      'and emits InputLoaded per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchInputs(sourceType: any(named: 'sourceType')),
        ).thenAnswer((_) => Stream.value([input()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchInputsEvent(sourceType: 'plant')),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        InputLoaded(inputs: [input()]),
      ],
      verify: (_) {
        verify(
          () => mockRepository.watchInputs(sourceType: 'plant'),
        ).called(1);
      },
    );

    blocTest<InputBloc, InputState>(
      'dispatching WatchInputsEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchInputs(sourceType: any(named: 'sourceType')),
        ).thenAnswer((_) => Stream.value([input()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchInputsEvent())
          ..add(WatchInputsEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(
          () => mockRepository.watchInputs(sourceType: any(named: 'sourceType')),
        ).called(1);
      },
    );

    blocTest<InputBloc, InputState>(
      "AddInputEvent success emits successMessage 'Input added' using the "
      'stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addInput(any()),
        ).thenAnswer((_) async => Right(input(id: 'input-2')));
        return buildBloc();
      },
      seed: () => InputLoaded(inputs: [input()]),
      act: (bloc) => bloc.add(AddInputEvent(input(id: 'input-2'))),
      expect: () => [
        InputLoaded(inputs: [input()], successMessage: 'Input added'),
      ],
    );

    blocTest<InputBloc, InputState>(
      "UpdateInputEvent success emits successMessage 'Input updated' "
      'without manually replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.updateInput(any()),
        ).thenAnswer((_) async => Right(input(cost: 999)));
        return buildBloc();
      },
      seed: () => InputLoaded(inputs: [input()]),
      act: (bloc) => bloc.add(UpdateInputEvent(input(cost: 999))),
      expect: () => [
        InputLoaded(inputs: [input()], successMessage: 'Input updated'),
      ],
    );

    blocTest<InputBloc, InputState>(
      "DeleteInputEvent success emits successMessage 'Input deleted' "
      'without manually removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.deleteInput(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => InputLoaded(inputs: [input()]),
      act: (bloc) => bloc.add(DeleteInputEvent('input-1')),
      expect: () => [
        InputLoaded(inputs: [input()], successMessage: 'Input deleted'),
      ],
    );

    blocTest<InputBloc, InputState>(
      'AddInputEvent failure emits InputError preserving current inputs',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addInput(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => InputLoaded(inputs: [input()]),
      act: (bloc) => bloc.add(AddInputEvent(input(id: 'input-2'))),
      expect: () => [
        InputError('boom', inputs: [input()]),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Input>> controller;

    setUp(() {
      controller = StreamController<List<Input>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<InputBloc, InputState>(
      'a stream error emits a non-fatal InputError over the last known '
      'inputs without crashing the bloc, and the subscription stays alive '
      'for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchInputs(sourceType: any(named: 'sourceType')),
        ).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => InputLoaded(inputs: [input()]),
      act: (bloc) async {
        bloc.add(WatchInputsEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([input(id: 'input-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        InputError(
          'Live sync interrupted. Pull to refresh.',
          inputs: [input()],
        ),
        InputLoaded(inputs: [input(id: 'input-2')]),
      ],
    );

    blocTest<InputBloc, InputState>(
      'a completed stream (onDone) does not emit any state or crash the '
      'bloc',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchInputs(sourceType: any(named: 'sourceType')),
        ).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => InputLoaded(inputs: [input()]),
      act: (bloc) async {
        bloc.add(WatchInputsEvent());
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      wait: const Duration(milliseconds: 50),
      expect: () => <InputState>[],
    );
  });

  group('online infinite scroll (P3-02a, flag off)', () {
    blocTest<InputBloc, InputState>(
      'GetInputsEvent under a full page sets hasReachedMax true and derives '
      'nextCursor from the last id',
      build: () {
        when(
          () => mockRepository.getInputs(
            sourceType: any(named: 'sourceType'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((_) async => Right([input(id: '3'), input(id: '2')]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetInputsEvent()),
      expect: () => [
        const InputLoading(),
        InputLoaded(inputs: [input(id: '3'), input(id: '2')], nextCursor: 2),
      ],
    );

    blocTest<InputBloc, InputState>(
      'LoadMoreInputsEvent is a no-op when hasReachedMax (a ≤500-row account '
      'never issues a second fetch)',
      build: buildBloc,
      seed: () => InputLoaded(inputs: [input(id: '2')], nextCursor: 2),
      act: (bloc) => bloc.add(LoadMoreInputsEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => <InputState>[],
      verify: (_) {
        verifyNever(
          () => mockRepository.getInputs(
            sourceType: any(named: 'sourceType'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        );
      },
    );

    blocTest<InputBloc, InputState>(
      'a full first page sets hasReachedMax false; LoadMore fetches with the '
      'cursor, APPENDS the next page and recomputes hasReachedMax/nextCursor',
      build: () {
        final page1 = List.generate(
          kOnlineListPageSize,
          (i) => input(id: '${1000 - i}'),
        );
        final page2 = [input(id: '500'), input(id: '499')];
        when(
          () => mockRepository.getInputs(
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
        bloc.add(GetInputsEvent());
        await bloc.stream.firstWhere((s) => s is InputLoaded);
        bloc.add(LoadMoreInputsEvent());
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const InputLoading(),
        isA<InputLoaded>()
            .having((s) => s.inputs.length, 'page 1 length',
                kOnlineListPageSize)
            .having((s) => s.hasReachedMax, 'hasReachedMax', false)
            .having((s) => s.nextCursor, 'nextCursor', 501),
        isA<InputLoaded>()
            .having((s) => s.inputs.length, 'appended length',
                kOnlineListPageSize + 2)
            .having((s) => s.hasReachedMax, 'hasReachedMax', true)
            .having((s) => s.nextCursor, 'nextCursor', 499),
      ],
      verify: (_) {
        verify(
          () => mockRepository.getInputs(
            sourceType: any(named: 'sourceType'),
            limit: any(named: 'limit'),
            cursor: 501,
          ),
        ).called(1);
      },
    );
  });
}
