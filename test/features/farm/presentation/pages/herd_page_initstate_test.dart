// Mirrors `animal_page_initstate_test.dart`'s shape: `HerdPage.initState`
// must dispatch `WatchHerdsEvent` (on `HerdBloc`, the PRIMARY bloc for this
// page) when the offline flag is on, and the legacy one-shot
// `GetHerdsEvent` when it is off — never both, never neither. The
// dependency-dropdown dispatch of `GetAnimalTypesEvent` on `AnimalTypeBloc`
// stays one-shot regardless of the flag (per the Task 8a ruling: leave
// cross-entity dependency-dropdown fetches ungated).
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/herd_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

Widget _wrap(HerdBloc bloc, AnimalTypeBloc animalTypeBloc) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<HerdBloc>.value(value: bloc),
      BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
    ],
    child: const MaterialApp(home: HerdPage()),
  );
}

void main() {
  late MockAnimalTypeBloc animalTypeBloc;

  setUpAll(() {
    registerFallbackValue(GetHerdsEvent());
    registerFallbackValue(WatchHerdsEvent());
    registerFallbackValue(GetAnimalTypesEvent());
  });

  setUp(() {
    animalTypeBloc = MockAnimalTypeBloc();
    whenListen(
      animalTypeBloc,
      const Stream<AnimalTypeState>.empty(),
      initialState: const AnimalTypeLoaded([]),
    );
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    testWidgets('does not refetch when herds already loaded', (tester) async {
      final bloc = MockHerdBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<HerdState>.empty(),
        initialState: HerdLoaded([
          Herd(
            id: 'herd-1',
            userId: 'user-1',
            name: 'North Herd',
            animalTypeId: 'type-1',
            location: 'North Field',
            initialHeadCount: 10,
            currentHeadCount: 10,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc));

      verifyNever(() => bloc.add(any(that: isA<GetHerdsEvent>())));
      verifyNever(() => bloc.add(any(that: isA<WatchHerdsEvent>())));
    });

    testWidgets('dispatches the one-shot GetHerdsEvent when not yet loaded', (
      tester,
    ) async {
      final bloc = MockHerdBloc();
      whenListen(
        bloc,
        const Stream<HerdState>.empty(),
        initialState: HerdInitial(),
      );
      // Not-yet-loaded so the dependency-dropdown dispatch actually fires
      // (mirrors the not-yet-loaded guard on the page itself).
      whenListen(
        animalTypeBloc,
        const Stream<AnimalTypeState>.empty(),
        initialState: AnimalTypeInitial(),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc));

      verify(() => bloc.add(any(that: isA<GetHerdsEvent>()))).called(1);
      verifyNever(() => bloc.add(any(that: isA<WatchHerdsEvent>())));
      // The dependency dropdown fetch stays one-shot, flag-off.
      verify(
        () => animalTypeBloc.add(any(that: isA<GetAnimalTypesEvent>())),
      ).called(1);
    });
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets('dispatches WatchHerdsEvent instead of GetHerdsEvent', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockHerdBloc();
      whenListen(
        bloc,
        const Stream<HerdState>.empty(),
        initialState: HerdInitial(),
      );
      // Not-yet-loaded so the dependency-dropdown dispatch actually fires
      // (mirrors the not-yet-loaded guard on the page itself).
      whenListen(
        animalTypeBloc,
        const Stream<AnimalTypeState>.empty(),
        initialState: AnimalTypeInitial(),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc));

      verify(() => bloc.add(any(that: isA<WatchHerdsEvent>()))).called(1);
      verifyNever(() => bloc.add(any(that: isA<GetHerdsEvent>())));
      // The dependency dropdown fetch stays one-shot even flag-on — a
      // dropdown only needs the local mirror read once, not reactively.
      verify(
        () => animalTypeBloc.add(any(that: isA<GetAnimalTypesEvent>())),
      ).called(1);
    });

    testWidgets('does not re-watch when herds already loaded', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockHerdBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<HerdState>.empty(),
        initialState: HerdLoaded([
          Herd(
            id: 'herd-1',
            userId: 'user-1',
            name: 'North Herd',
            animalTypeId: 'type-1',
            location: 'North Field',
            initialHeadCount: 10,
            currentHeadCount: 10,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc));

      verifyNever(() => bloc.add(any(that: isA<WatchHerdsEvent>())));
      verifyNever(() => bloc.add(any(that: isA<GetHerdsEvent>())));
    });
  });
}
