import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_seasons.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_seasons.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetSeasons extends Mock implements GetSeasons {}

class MockAddSeason extends Mock implements AddSeason {}

class MockUpdateSeason extends Mock implements UpdateSeason {}

class MockDeleteSeason extends Mock implements DeleteSeason {}

class MockWatchSeasons extends Mock implements WatchSeasons {}

void main() {
  final now = DateTime.now();
  Season season({String id = 'season-1', String name = 'Long Rains 2026'}) =>
      Season(
        id: id,
        userId: 'user-1',
        name: name,
        plantId: 'plant-1',
        landId: 'land-1',
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

  late MockGetSeasons mockGetSeasons;
  late MockAddSeason mockAddSeason;
  late MockUpdateSeason mockUpdateSeason;
  late MockDeleteSeason mockDeleteSeason;
  late MockWatchSeasons mockWatchSeasons;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(AddSeasonParams(season: season()));
    registerFallbackValue(UpdateSeasonParams(season: season()));
    registerFallbackValue(DeleteSeasonParams(id: 'season-1'));
  });

  setUp(() {
    mockGetSeasons = MockGetSeasons();
    mockAddSeason = MockAddSeason();
    mockUpdateSeason = MockUpdateSeason();
    mockDeleteSeason = MockDeleteSeason();
    mockWatchSeasons = MockWatchSeasons();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  SeasonBloc buildBloc() => SeasonBloc(
    getSeasons: mockGetSeasons,
    addSeason: mockAddSeason,
    updateSeason: mockUpdateSeason,
    deleteSeason: mockDeleteSeason,
    watchSeasons: mockWatchSeasons,
  );

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    blocTest<SeasonBloc, SeasonState>(
      'GetSeasonsEvent emits [SeasonLoading, SeasonLoaded] from the use '
      'case',
      build: () {
        when(
          () => mockGetSeasons(any()),
        ).thenAnswer((_) async => Right([season()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GetSeasonsEvent()),
      expect: () => [
        const SeasonLoading(),
        SeasonLoaded(seasons: [season()]),
      ],
    );

    blocTest<SeasonBloc, SeasonState>(
      'AddSeasonEvent success appends the returned season and sets '
      "successMessage 'Season created'",
      build: () {
        when(
          () => mockAddSeason(any()),
        ).thenAnswer((_) async => Right(season(id: 'season-2')));
        return buildBloc();
      },
      seed: () => SeasonLoaded(seasons: [season()]),
      act: (bloc) => bloc.add(AddSeasonEvent(season(id: 'season-2'))),
      expect: () => [
        isA<SeasonLoading>(),
        SeasonLoaded(
          seasons: [season(), season(id: 'season-2')],
          successMessage: 'Season created',
        ),
      ],
    );

    blocTest<SeasonBloc, SeasonState>(
      'AddSeasonEvent failure emits SeasonError preserving current seasons',
      build: () {
        when(
          () => mockAddSeason(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => SeasonLoaded(seasons: [season()]),
      act: (bloc) => bloc.add(AddSeasonEvent(season(id: 'season-2'))),
      expect: () => [
        isA<SeasonLoading>(),
        SeasonError('boom', seasons: [season()]),
      ],
    );
  });

  group('flag ON (reactive stream)', () {
    blocTest<SeasonBloc, SeasonState>(
      'WatchSeasonsEvent subscribes to repository.watchSeasons() and emits '
      'SeasonLoaded per emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchSeasons(),
        ).thenAnswer((_) => Stream.value([season()]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(WatchSeasonsEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        SeasonLoaded(seasons: [season()]),
      ],
    );

    blocTest<SeasonBloc, SeasonState>(
      'dispatching WatchSeasonsEvent twice in a row opens only one '
      'subscription (idempotent guard, no race/leak)',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockWatchSeasons(),
        ).thenAnswer((_) => Stream.value([season()]));
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(WatchSeasonsEvent())
          ..add(WatchSeasonsEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verify(() => mockWatchSeasons()).called(1);
      },
    );

    blocTest<SeasonBloc, SeasonState>(
      "AddSeasonEvent success emits successMessage 'Season created' using "
      'the stream-driven list — NOT a manual append',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddSeason(any()),
        ).thenAnswer((_) async => Right(season(id: 'season-2')));
        return buildBloc();
      },
      seed: () => SeasonLoaded(seasons: [season()]),
      act: (bloc) => bloc.add(AddSeasonEvent(season(id: 'season-2'))),
      expect: () => [
        SeasonLoaded(seasons: [season()], successMessage: 'Season created'),
      ],
    );

    blocTest<SeasonBloc, SeasonState>(
      "UpdateSeasonEvent success emits successMessage 'Season updated' "
      'without manually replacing the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockUpdateSeason(any()),
        ).thenAnswer((_) async => Right(season(name: 'Renamed')));
        return buildBloc();
      },
      seed: () => SeasonLoaded(seasons: [season()]),
      act: (bloc) => bloc.add(UpdateSeasonEvent(season(name: 'Renamed'))),
      expect: () => [
        SeasonLoaded(seasons: [season()], successMessage: 'Season updated'),
      ],
    );

    blocTest<SeasonBloc, SeasonState>(
      "DeleteSeasonEvent success emits successMessage 'Season deleted' "
      'without manually removing from the list',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockDeleteSeason(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => SeasonLoaded(seasons: [season()]),
      act: (bloc) => bloc.add(DeleteSeasonEvent('season-1')),
      expect: () => [
        SeasonLoaded(seasons: [season()], successMessage: 'Season deleted'),
      ],
    );

    blocTest<SeasonBloc, SeasonState>(
      'AddSeasonEvent failure emits SeasonError preserving current seasons',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(
          () => mockAddSeason(any()),
        ).thenAnswer((_) async => const Left(ServerFailure('boom')));
        return buildBloc();
      },
      seed: () => SeasonLoaded(seasons: [season()]),
      act: (bloc) => bloc.add(AddSeasonEvent(season(id: 'season-2'))),
      expect: () => [
        SeasonError('boom', seasons: [season()]),
      ],
    );
  });

  group('watch stream resilience (onError / onDone)', () {
    late StreamController<List<Season>> controller;

    setUp(() {
      controller = StreamController<List<Season>>();
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    blocTest<SeasonBloc, SeasonState>(
      'a stream error emits a non-fatal SeasonError over the last known '
      'seasons without crashing the bloc, and the subscription stays alive '
      'for a later emission',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockWatchSeasons()).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => SeasonLoaded(seasons: [season()]),
      act: (bloc) async {
        bloc.add(WatchSeasonsEvent());
        await Future<void>.delayed(Duration.zero);
        controller.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);
        controller.add([season(id: 'season-2')]);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        SeasonError(
          'Live sync interrupted. Pull to refresh.',
          seasons: [season()],
        ),
        SeasonLoaded(seasons: [season(id: 'season-2')]),
      ],
    );

    blocTest<SeasonBloc, SeasonState>(
      'a completed stream (onDone) does not emit any state or crash the '
      'bloc',
      setUp: () => OfflineConfig.enabled = true,
      build: () {
        when(() => mockWatchSeasons()).thenAnswer((_) => controller.stream);
        return buildBloc();
      },
      seed: () => SeasonLoaded(seasons: [season()]),
      act: (bloc) async {
        bloc.add(WatchSeasonsEvent());
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      wait: const Duration(milliseconds: 50),
      expect: () => <SeasonState>[],
    );
  });
}
