import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_animal_types.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_animal_types.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAnimalTypes extends Mock implements GetAnimalTypes {}

class MockAddAnimalType extends Mock implements AddAnimalType {}

class MockUpdateAnimalType extends Mock implements UpdateAnimalType {}

class MockDeleteAnimalType extends Mock implements DeleteAnimalType {}

class MockWatchAnimalTypes extends Mock implements WatchAnimalTypes {}

void main() {
  final now = DateTime.now();
  AnimalType animalType({String id = 'type-1', String name = 'Cattle'}) =>
      AnimalType(id: id, userId: 'user-1', name: name, createdAt: now, updatedAt: now);

  late MockGetAnimalTypes mockGetAnimalTypes;
  late MockAddAnimalType mockAddAnimalType;
  late MockUpdateAnimalType mockUpdateAnimalType;
  late MockDeleteAnimalType mockDeleteAnimalType;
  late MockWatchAnimalTypes mockWatchAnimalTypes;

  setUpAll(() {
    registerFallbackValue(NoParams());
  });

  setUp(() {
    mockGetAnimalTypes = MockGetAnimalTypes();
    mockAddAnimalType = MockAddAnimalType();
    mockUpdateAnimalType = MockUpdateAnimalType();
    mockDeleteAnimalType = MockDeleteAnimalType();
    mockWatchAnimalTypes = MockWatchAnimalTypes();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  AnimalTypeBloc buildBloc() => AnimalTypeBloc(
    getAnimalTypes: mockGetAnimalTypes,
    addAnimalType: mockAddAnimalType,
    updateAnimalType: mockUpdateAnimalType,
    deleteAnimalType: mockDeleteAnimalType,
    watchAnimalTypes: mockWatchAnimalTypes,
  );

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<AnimalTypeBloc, AnimalTypeState>(
      'GetAnimalTypesEvent emits [AnimalTypeLoading, AnimalTypeLoaded] from '
      'the use case',
      build: () {
        when(
          () => mockGetAnimalTypes(any()),
        ).thenAnswer((_) async => Right([animalType()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetAnimalTypesEvent()),
      expect: () => [
        const AnimalTypeLoading(),
        AnimalTypeLoaded([animalType()]),
      ],
    );

    blocTest<AnimalTypeBloc, AnimalTypeState>(
      "AddAnimalTypeEvent success appends the returned animal type and sets "
      "successMessage 'Animal type added'",
      build: () {
        when(
          () => mockAddAnimalType(any(), any(), any()),
        ).thenAnswer((_) async => Right(animalType(id: 'type-2')));
        return buildBloc();
      },
      seed: () => AnimalTypeLoaded([animalType()]),
      act: (bloc) => bloc.add(
        const AddAnimalTypeEvent('Cattle', null, 'user-1'),
      ),
      expect: () => [
        isA<AnimalTypeLoading>(),
        AnimalTypeLoaded(
          [animalType(), animalType(id: 'type-2')],
          successMessage: 'Animal type added',
        ),
      ],
    );

    blocTest<AnimalTypeBloc, AnimalTypeState>(
      'AddAnimalTypeEvent failure emits AnimalTypeError preserving current '
      'animalTypes',
      build: () {
        when(
          () => mockAddAnimalType(any(), any(), any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => AnimalTypeLoaded([animalType()]),
      act: (bloc) => bloc.add(
        const AddAnimalTypeEvent('Cattle', null, 'user-1'),
      ),
      expect: () => [
        isA<AnimalTypeLoading>(),
        AnimalTypeError('boom', animalTypes: [animalType()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<AnimalTypeBloc, AnimalTypeState>(
      'WatchAnimalTypesEvent subscribes to repository.watchAnimalTypes() '
      'and emits AnimalTypeLoaded per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchAnimalTypes(),
        ).thenAnswer((_) => Stream.value([animalType()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchAnimalTypesEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        AnimalTypeLoaded([animalType()]),
      ],
    );

    blocTest<AnimalTypeBloc, AnimalTypeState>(
      'dispatching WatchAnimalTypesEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchAnimalTypes(),
        ).thenAnswer((_) => Stream.value([animalType()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchAnimalTypesEvent())
          ..add(WatchAnimalTypesEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(() => mockWatchAnimalTypes()).called(1);
      },
    );

    blocTest<AnimalTypeBloc, AnimalTypeState>(
      "AddAnimalTypeEvent success emits successMessage 'Animal type added' "
      'using the stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddAnimalType(any(), any(), any()),
        ).thenAnswer((_) async => Right(animalType(id: 'type-2')));
        return buildBloc();
      },
      seed: () => AnimalTypeLoaded([animalType()]),
      act: (bloc) => bloc.add(
        const AddAnimalTypeEvent('Cattle', null, 'user-1'),
      ),
      expect: () => [
        AnimalTypeLoaded(
          [animalType()],
          successMessage: 'Animal type added',
        ),
      ],
    );

    blocTest<AnimalTypeBloc, AnimalTypeState>(
      "UpdateAnimalTypeEvent success emits successMessage 'Animal type "
      "updated' without manually replacing the list",
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockUpdateAnimalType(any(), any(), any()),
        ).thenAnswer((_) async => Right(animalType(name: 'Renamed')));
        return buildBloc();
      },
      seed: () => AnimalTypeLoaded([animalType()]),
      act: (bloc) => bloc.add(
        const UpdateAnimalTypeEvent('type-1', 'Renamed', null),
      ),
      expect: () => [
        AnimalTypeLoaded(
          [animalType()],
          successMessage: 'Animal type updated',
        ),
      ],
    );

    blocTest<AnimalTypeBloc, AnimalTypeState>(
      "DeleteAnimalTypeEvent success emits successMessage 'Animal type "
      "deleted' without manually removing from the list",
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockDeleteAnimalType(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => AnimalTypeLoaded([animalType()]),
      act: (bloc) => bloc.add(const DeleteAnimalTypeEvent('type-1')),
      expect: () => [
        AnimalTypeLoaded(
          [animalType()],
          successMessage: 'Animal type deleted',
        ),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<AnimalType>> controller;

    setUp(() {
      controller = StreamController<List<AnimalType>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<AnimalTypeBloc, AnimalTypeState>(
      'a stream error emits a non-fatal AnimalTypeError over the last '
      'known animalTypes without crashing the bloc, and the subscription '
      'stays alive for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockWatchAnimalTypes()).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => AnimalTypeLoaded([animalType()]),
      act: (bloc) async {
        bloc.add(WatchAnimalTypesEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([animalType(id: 'type-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        AnimalTypeError(
          'Live sync interrupted. Pull to refresh.',
          animalTypes: [animalType()],
        ),
        AnimalTypeLoaded([animalType(id: 'type-2')]),
      ],
    );
  });
}
