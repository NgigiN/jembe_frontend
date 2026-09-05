import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_lands.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_lands.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetLands extends Mock implements GetLands {}

class MockAddLand extends Mock implements AddLand {}

class MockUpdateLand extends Mock implements UpdateLand {}

class MockDeleteLand extends Mock implements DeleteLand {}

class MockWatchLands extends Mock implements WatchLands {}

void main() {
  final now = DateTime.now();
  Land land({String id = 'land-1', String name = 'North Field'}) => Land(
    id: id,
    userId: 'user-1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );

  late MockGetLands mockGetLands;
  late MockAddLand mockAddLand;
  late MockUpdateLand mockUpdateLand;
  late MockDeleteLand mockDeleteLand;
  late MockWatchLands mockWatchLands;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(AddLandParams(land: land()));
    registerFallbackValue(UpdateLandParams(land: land()));
    registerFallbackValue(DeleteLandParams(id: 'land-1'));
  });

  setUp(() {
    mockGetLands = MockGetLands();
    mockAddLand = MockAddLand();
    mockUpdateLand = MockUpdateLand();
    mockDeleteLand = MockDeleteLand();
    mockWatchLands = MockWatchLands();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  LandBloc buildBloc() => LandBloc(
    getLands: mockGetLands,
    addLand: mockAddLand,
    updateLand: mockUpdateLand,
    deleteLand: mockDeleteLand,
    watchLands: mockWatchLands,
  );

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<LandBloc, LandState>(
      'GetLandsEvent emits [LandLoading, LandLoaded] from the use case',
      build: () {
        when(
          () => mockGetLands(any()),
        ).thenAnswer((_) async => Right([land()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetLandsEvent()),
      expect: () => [
        const LandLoading(),
        LandLoaded(lands: [land()]),
      ],
    );

    blocTest<LandBloc, LandState>(
      'AddLandEvent success appends the returned land and sets '
      "successMessage 'Land added'",
      build: () {
        when(
          () => mockAddLand(any()),
        ).thenAnswer((_) async => Right(land(id: 'land-2')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(AddLandEvent(land(id: 'land-2'))),
      expect: () => [
        isA<LandLoading>(),
        LandLoaded(
          lands: [
            land(),
            land(id: 'land-2'),
          ],
          successMessage: 'Land added',
        ),
      ],
    );

    blocTest<LandBloc, LandState>(
      'AddLandEvent failure emits LandError preserving current lands',
      build: () {
        when(
          () => mockAddLand(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(AddLandEvent(land(id: 'land-2'))),
      expect: () => [
        isA<LandLoading>(),
        LandError('boom', lands: [land()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<LandBloc, LandState>(
      'WatchLandsEvent subscribes to repository.watchLands() and emits '
      'LandLoaded per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockWatchLands()).thenAnswer((_) => Stream.value([land()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchLandsEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        LandLoaded(lands: [land()]),
      ],
    );

    blocTest<LandBloc, LandState>(
      "AddLandEvent success emits successMessage 'Land added' using the "
      'stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        // The use case "succeeds" with a different land than what's already
        // in state, to prove the emitted list is untouched by the result
        // (i.e. no manual append) — only a real stream emission would add
        // it, and this test deliberately never seeds one.
        when(
          () => mockAddLand(any()),
        ).thenAnswer((_) async => Right(land(id: 'land-2')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(AddLandEvent(land(id: 'land-2'))),
      expect: () => [
        LandLoaded(lands: [land()], successMessage: 'Land added'),
      ],
    );

    blocTest<LandBloc, LandState>(
      "UpdateLandEvent success emits successMessage 'Land updated' without "
      'manually replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockUpdateLand(any()),
        ).thenAnswer((_) async => Right(land(name: 'Renamed')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(UpdateLandEvent(land(name: 'Renamed'))),
      expect: () => [
        LandLoaded(lands: [land()], successMessage: 'Land updated'),
      ],
    );

    blocTest<LandBloc, LandState>(
      "DeleteLandEvent success emits successMessage 'Land deleted' without "
      'manually removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockDeleteLand(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(DeleteLandEvent('land-1')),
      expect: () => [
        LandLoaded(lands: [land()], successMessage: 'Land deleted'),
      ],
    );

    blocTest<LandBloc, LandState>(
      'AddLandEvent failure emits LandError preserving current lands',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddLand(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => LandLoaded(lands: [land()]),
      act: (bloc) => bloc.add(AddLandEvent(land(id: 'land-2'))),
      expect: () => [
        LandError('boom', lands: [land()]),
      ],
    );
  });
}
