import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/constants/list_pagination.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnimalRepository extends Mock implements AnimalRepository {}

void main() {
  final now = DateTime.now();
  final birthDate = DateTime(2024);
  Animal animal({String id = 'animal-1', String name = 'Bessie'}) => Animal(
    id: id,
    userId: 'user-1',
    name: name,
    animalTypeId: 'type-1',
    herdId: 'herd-1',
    birthDate: birthDate,
    createdAt: now,
    updatedAt: now,
  );

  late MockAnimalRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(animal());
  });

  setUp(() {
    mockRepository = MockAnimalRepository();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  AnimalBloc buildBloc() => AnimalBloc(repository: mockRepository);

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<AnimalBloc, AnimalState>(
      'GetAnimalsEvent emits [AnimalLoading, AnimalLoaded] from the repository',
      build: () {
        when(
          () => mockRepository.getAnimals(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Right([animal()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetAnimalsEvent()),
      expect: () => [
        const AnimalLoading(),
        AnimalLoaded(animals: [animal()]),
      ],
    );

    blocTest<AnimalBloc, AnimalState>(
      "AddAnimalEvent success appends the returned animal and sets "
      "successMessage 'Animal added'",
      build: () {
        when(
          () => mockRepository.addAnimal(any()),
        ).thenAnswer((_) async => Right(animal(id: 'animal-2')));
        return buildBloc();
      },
      seed: () => AnimalLoaded(animals: [animal()]),
      act: (bloc) => bloc.add(AddAnimalEvent(animal(id: 'animal-2'))),
      expect: () => [
        isA<AnimalLoading>(),
        AnimalLoaded(
          animals: [animal(), animal(id: 'animal-2')],
          successMessage: 'Animal added',
        ),
      ],
    );

    blocTest<AnimalBloc, AnimalState>(
      'AddAnimalEvent failure emits AnimalError preserving current animals',
      build: () {
        when(
          () => mockRepository.addAnimal(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => AnimalLoaded(animals: [animal()]),
      act: (bloc) => bloc.add(AddAnimalEvent(animal(id: 'animal-2'))),
      expect: () => [
        isA<AnimalLoading>(),
        AnimalError('boom', animals: [animal()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<AnimalBloc, AnimalState>(
      'WatchAnimalsEvent subscribes to repository.watchAnimals() and emits '
      'AnimalLoaded per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchAnimals(),
        ).thenAnswer((_) => Stream.value([animal()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchAnimalsEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        AnimalLoaded(animals: [animal()]),
      ],
    );

    blocTest<AnimalBloc, AnimalState>(
      'dispatching WatchAnimalsEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.watchAnimals(),
        ).thenAnswer((_) => Stream.value([animal()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchAnimalsEvent())
          ..add(WatchAnimalsEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(() => mockRepository.watchAnimals()).called(1);
      },
    );

    blocTest<AnimalBloc, AnimalState>(
      "AddAnimalEvent success emits successMessage 'Animal added' using the "
      'stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addAnimal(any()),
        ).thenAnswer((_) async => Right(animal(id: 'animal-2')));
        return buildBloc();
      },
      seed: () => AnimalLoaded(animals: [animal()]),
      act: (bloc) => bloc.add(AddAnimalEvent(animal(id: 'animal-2'))),
      expect: () => [
        AnimalLoaded(animals: [animal()], successMessage: 'Animal added'),
      ],
    );

    blocTest<AnimalBloc, AnimalState>(
      "UpdateAnimalEvent success emits successMessage 'Animal updated' "
      'without manually replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.updateAnimal(any()),
        ).thenAnswer((_) async => Right(animal(name: 'Renamed')));
        return buildBloc();
      },
      seed: () => AnimalLoaded(animals: [animal()]),
      act: (bloc) => bloc.add(UpdateAnimalEvent(animal(name: 'Renamed'))),
      expect: () => [
        AnimalLoaded(animals: [animal()], successMessage: 'Animal updated'),
      ],
    );

    blocTest<AnimalBloc, AnimalState>(
      "DeleteAnimalEvent success emits successMessage 'Animal deleted' "
      'without manually removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.deleteAnimal(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => AnimalLoaded(animals: [animal()]),
      act: (bloc) => bloc.add(DeleteAnimalEvent('animal-1')),
      expect: () => [
        AnimalLoaded(animals: [animal()], successMessage: 'Animal deleted'),
      ],
    );

    blocTest<AnimalBloc, AnimalState>(
      'AddAnimalEvent failure emits AnimalError preserving current animals',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockRepository.addAnimal(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => AnimalLoaded(animals: [animal()]),
      act: (bloc) => bloc.add(AddAnimalEvent(animal(id: 'animal-2'))),
      expect: () => [
        AnimalError('boom', animals: [animal()]),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Animal>> controller;

    setUp(() {
      controller = StreamController<List<Animal>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<AnimalBloc, AnimalState>(
      'a stream error emits a non-fatal AnimalError over the last known '
      'animals without crashing the bloc, and the subscription stays alive '
      'for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchAnimals())
            .thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => AnimalLoaded(animals: [animal()]),
      act: (bloc) async {
        bloc.add(WatchAnimalsEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([animal(id: 'animal-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        AnimalError(
          'Live sync interrupted. Pull to refresh.',
          animals: [animal()],
        ),
        AnimalLoaded(animals: [animal(id: 'animal-2')]),
      ],
    );

    blocTest<AnimalBloc, AnimalState>(
      'a completed stream (onDone) does not emit any state or crash the '
      'bloc',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockRepository.watchAnimals())
            .thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => AnimalLoaded(animals: [animal()]),
      act: (bloc) async {
        bloc.add(WatchAnimalsEvent());
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      wait: const Duration(milliseconds: 50),
      expect: () => <AnimalState>[],
    );
  });

  group('online infinite scroll (P3-02a, flag off)', () {
    blocTest<AnimalBloc, AnimalState>(
      'GetAnimalsEvent under a full page sets hasReachedMax true and '
      'derives nextCursor from the last id',
      build: () {
        when(
          () => mockRepository.getAnimals(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => Right([animal(id: '3'), animal(id: '2')]),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetAnimalsEvent()),
      expect: () => [
        const AnimalLoading(),
        AnimalLoaded(
          animals: [animal(id: '3'), animal(id: '2')],
          nextCursor: 2,
        ),
      ],
    );

    blocTest<AnimalBloc, AnimalState>(
      'LoadMoreAnimalsEvent is a no-op when hasReachedMax (a ≤500-row '
      'account never issues a second fetch)',
      build: buildBloc,
      seed: () => AnimalLoaded(animals: [animal(id: '2')], nextCursor: 2),
      act: (bloc) => bloc.add(LoadMoreAnimalsEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => <AnimalState>[],
      verify: (_) {
        verifyNever(
          () => mockRepository.getAnimals(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        );
      },
    );

    blocTest<AnimalBloc, AnimalState>(
      'a full first page sets hasReachedMax false; LoadMore fetches with '
      'the cursor, APPENDS the next page and recomputes '
      'hasReachedMax/nextCursor',
      build: () {
        final page1 = List.generate(
          kOnlineListPageSize,
          (i) => animal(id: '${1000 - i}'),
        );
        final page2 = [animal(id: '500'), animal(id: '499')];
        when(
          () => mockRepository.getAnimals(
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
        bloc.add(GetAnimalsEvent());
        await bloc.stream.firstWhere((s) => s is AnimalLoaded);
        bloc.add(LoadMoreAnimalsEvent());
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const AnimalLoading(),
        isA<AnimalLoaded>()
            .having((s) => s.animals.length, 'page 1 length',
                kOnlineListPageSize)
            .having((s) => s.hasReachedMax, 'hasReachedMax', false)
            .having((s) => s.nextCursor, 'nextCursor', 501),
        isA<AnimalLoaded>()
            .having((s) => s.animals.length, 'appended length',
                kOnlineListPageSize + 2)
            .having((s) => s.hasReachedMax, 'hasReachedMax', true)
            .having((s) => s.nextCursor, 'nextCursor', 499),
      ],
      verify: (_) {
        verify(
          () => mockRepository.getAnimals(
            limit: any(named: 'limit'),
            cursor: 501,
          ),
        ).called(1);
      },
    );
  });
}
