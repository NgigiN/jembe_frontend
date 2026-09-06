import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_animals.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_animals.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAnimals extends Mock implements GetAnimals {}

class MockAddAnimal extends Mock implements AddAnimal {}

class MockUpdateAnimal extends Mock implements UpdateAnimal {}

class MockDeleteAnimal extends Mock implements DeleteAnimal {}

class MockWatchAnimals extends Mock implements WatchAnimals {}

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

  late MockGetAnimals mockGetAnimals;
  late MockAddAnimal mockAddAnimal;
  late MockUpdateAnimal mockUpdateAnimal;
  late MockDeleteAnimal mockDeleteAnimal;
  late MockWatchAnimals mockWatchAnimals;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(AddAnimalParams(animal: animal()));
    registerFallbackValue(UpdateAnimalParams(animal: animal()));
    registerFallbackValue(DeleteAnimalParams(id: 'animal-1'));
  });

  setUp(() {
    mockGetAnimals = MockGetAnimals();
    mockAddAnimal = MockAddAnimal();
    mockUpdateAnimal = MockUpdateAnimal();
    mockDeleteAnimal = MockDeleteAnimal();
    mockWatchAnimals = MockWatchAnimals();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  AnimalBloc buildBloc() => AnimalBloc(
    getAnimals: mockGetAnimals,
    addAnimal: mockAddAnimal,
    updateAnimal: mockUpdateAnimal,
    deleteAnimal: mockDeleteAnimal,
    watchAnimals: mockWatchAnimals,
  );

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<AnimalBloc, AnimalState>(
      'GetAnimalsEvent emits [AnimalLoading, AnimalLoaded] from the use case',
      build: () {
        when(
          () => mockGetAnimals(any()),
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
          () => mockAddAnimal(any()),
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
          () => mockAddAnimal(any()),
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
          () => mockWatchAnimals(),
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
          () => mockWatchAnimals(),
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
        verify(() => mockWatchAnimals()).called(1);
      },
    );

    blocTest<AnimalBloc, AnimalState>(
      "AddAnimalEvent success emits successMessage 'Animal added' using the "
      'stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddAnimal(any()),
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
          () => mockUpdateAnimal(any()),
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
          () => mockDeleteAnimal(any()),
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
          () => mockAddAnimal(any()),
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
        when(() => mockWatchAnimals()).thenAnswer((_) => controller.stream);
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
        when(() => mockWatchAnimals()).thenAnswer((_) => controller.stream);
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
}
