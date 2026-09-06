import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_plants.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_plants.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetPlants extends Mock implements GetPlants {}

class MockAddPlant extends Mock implements AddPlant {}

class MockUpdatePlant extends Mock implements UpdatePlant {}

class MockDeletePlant extends Mock implements DeletePlant {}

class MockWatchPlants extends Mock implements WatchPlants {}

void main() {
  final now = DateTime.now();
  Plant plant({String id = 'plant-1', String name = 'Maize'}) => Plant(
    id: id,
    userId: 'user-1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );

  late MockGetPlants mockGetPlants;
  late MockAddPlant mockAddPlant;
  late MockUpdatePlant mockUpdatePlant;
  late MockDeletePlant mockDeletePlant;
  late MockWatchPlants mockWatchPlants;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(AddPlantParams(plant: plant()));
    registerFallbackValue(UpdatePlantParams(plant: plant()));
    registerFallbackValue(DeletePlantParams(id: 'plant-1'));
  });

  setUp(() {
    mockGetPlants = MockGetPlants();
    mockAddPlant = MockAddPlant();
    mockUpdatePlant = MockUpdatePlant();
    mockDeletePlant = MockDeletePlant();
    mockWatchPlants = MockWatchPlants();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  PlantBloc buildBloc() => PlantBloc(
    getPlants: mockGetPlants,
    addPlant: mockAddPlant,
    updatePlant: mockUpdatePlant,
    deletePlant: mockDeletePlant,
    watchPlants: mockWatchPlants,
  );

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<PlantBloc, PlantState>(
      'GetPlantsEvent emits [PlantLoading, PlantLoaded] from the use case',
      build: () {
        when(
          () => mockGetPlants(any()),
        ).thenAnswer((_) async => Right([plant()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetPlantsEvent()),
      expect: () => [
        const PlantLoading(),
        PlantLoaded(plants: [plant()]),
      ],
    );

    blocTest<PlantBloc, PlantState>(
      'AddPlantEvent success appends the returned plant and sets '
      "successMessage 'Crop added'",
      build: () {
        when(
          () => mockAddPlant(any()),
        ).thenAnswer((_) async => Right(plant(id: 'plant-2')));
        return buildBloc();
      },
      seed: () => PlantLoaded(plants: [plant()]),
      act: (bloc) => bloc.add(AddPlantEvent(plant(id: 'plant-2'))),
      expect: () => [
        isA<PlantLoading>(),
        PlantLoaded(
          plants: [plant(), plant(id: 'plant-2')],
          successMessage: 'Crop added',
        ),
      ],
    );

    blocTest<PlantBloc, PlantState>(
      'AddPlantEvent failure emits PlantError preserving current plants',
      build: () {
        when(
          () => mockAddPlant(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => PlantLoaded(plants: [plant()]),
      act: (bloc) => bloc.add(AddPlantEvent(plant(id: 'plant-2'))),
      expect: () => [
        isA<PlantLoading>(),
        PlantError('boom', plants: [plant()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<PlantBloc, PlantState>(
      'WatchPlantsEvent subscribes to repository.watchPlants() and emits '
      'PlantLoaded per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchPlants(),
        ).thenAnswer((_) => Stream.value([plant()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchPlantsEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        PlantLoaded(plants: [plant()]),
      ],
    );

    blocTest<PlantBloc, PlantState>(
      'dispatching WatchPlantsEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchPlants(),
        ).thenAnswer((_) => Stream.value([plant()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchPlantsEvent())
          ..add(WatchPlantsEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(() => mockWatchPlants()).called(1);
      },
    );

    blocTest<PlantBloc, PlantState>(
      "AddPlantEvent success emits successMessage 'Crop added' using the "
      'stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddPlant(any()),
        ).thenAnswer((_) async => Right(plant(id: 'plant-2')));
        return buildBloc();
      },
      seed: () => PlantLoaded(plants: [plant()]),
      act: (bloc) => bloc.add(AddPlantEvent(plant(id: 'plant-2'))),
      expect: () => [
        PlantLoaded(plants: [plant()], successMessage: 'Crop added'),
      ],
    );

    blocTest<PlantBloc, PlantState>(
      "UpdatePlantEvent success emits successMessage 'Crop updated' without "
      'manually replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockUpdatePlant(any()),
        ).thenAnswer((_) async => Right(plant(name: 'Renamed')));
        return buildBloc();
      },
      seed: () => PlantLoaded(plants: [plant()]),
      act: (bloc) => bloc.add(UpdatePlantEvent(plant(name: 'Renamed'))),
      expect: () => [
        PlantLoaded(plants: [plant()], successMessage: 'Crop updated'),
      ],
    );

    blocTest<PlantBloc, PlantState>(
      "DeletePlantEvent success emits successMessage 'Crop deleted' without "
      'manually removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockDeletePlant(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => PlantLoaded(plants: [plant()]),
      act: (bloc) => bloc.add(DeletePlantEvent('plant-1')),
      expect: () => [
        PlantLoaded(plants: [plant()], successMessage: 'Crop deleted'),
      ],
    );

    blocTest<PlantBloc, PlantState>(
      'AddPlantEvent failure emits PlantError preserving current plants',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddPlant(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => PlantLoaded(plants: [plant()]),
      act: (bloc) => bloc.add(AddPlantEvent(plant(id: 'plant-2'))),
      expect: () => [
        PlantError('boom', plants: [plant()]),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Plant>> controller;

    setUp(() {
      controller = StreamController<List<Plant>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<PlantBloc, PlantState>(
      'a stream error emits a non-fatal PlantError over the last known '
      'plants without crashing the bloc, and the subscription stays alive '
      'for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockWatchPlants()).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => PlantLoaded(plants: [plant()]),
      act: (bloc) async {
        bloc.add(WatchPlantsEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([plant(id: 'plant-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        PlantError('Live sync interrupted. Pull to refresh.', plants: [plant()]),
        PlantLoaded(plants: [plant(id: 'plant-2')]),
      ],
    );

    blocTest<PlantBloc, PlantState>(
      'a completed stream (onDone) does not emit any state or crash the '
      'bloc',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockWatchPlants()).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => PlantLoaded(plants: [plant()]),
      act: (bloc) async {
        bloc.add(WatchPlantsEvent());
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      wait: const Duration(milliseconds: 50),
      expect: () => <PlantState>[],
    );
  });
}
