// Mirrors `plant_page_initstate_test.dart`'s shape: `AnimalPage.initState`
// must dispatch `WatchAnimalsEvent` when the offline flag is on, and the
// legacy one-shot `GetAnimalsEvent` when it is off — never both, never
// neither.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnimalBloc extends MockBloc<AnimalEvent, AnimalState>
    implements AnimalBloc {}

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState>
    implements HerdBloc {}

Widget _wrap(AnimalBloc bloc, AnimalTypeBloc typeBloc, HerdBloc herdBloc) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<AnimalBloc>.value(value: bloc),
      BlocProvider<AnimalTypeBloc>.value(value: typeBloc),
      BlocProvider<HerdBloc>.value(value: herdBloc),
    ],
    child: const MaterialApp(home: AnimalPage()),
  );
}

void main() {
  late MockAnimalTypeBloc animalTypeBloc;
  late MockHerdBloc herdBloc;

  setUpAll(() {
    registerFallbackValue(GetAnimalsEvent());
    registerFallbackValue(WatchAnimalsEvent());
    registerFallbackValue(GetAnimalTypesEvent());
    registerFallbackValue(GetHerdsEvent());
  });

  setUp(() {
    animalTypeBloc = MockAnimalTypeBloc();
    herdBloc = MockHerdBloc();
    whenListen(
      animalTypeBloc,
      const Stream<AnimalTypeState>.empty(),
      initialState: const AnimalTypeLoaded([]),
    );
    whenListen(
      herdBloc,
      const Stream<HerdState>.empty(),
      initialState: const HerdLoaded([]),
    );
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    testWidgets('does not refetch when animals already loaded', (
      tester,
    ) async {
      final bloc = MockAnimalBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<AnimalState>.empty(),
        initialState: AnimalLoaded(
          animals: [
            Animal(
              id: 'animal-1',
              userId: 'user-1',
              name: 'Bessie',
              animalTypeId: 'type-1',
              herdId: 'herd-1',
              birthDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc, herdBloc));

      verifyNever(() => bloc.add(any(that: isA<GetAnimalsEvent>())));
      verifyNever(() => bloc.add(any(that: isA<WatchAnimalsEvent>())));
    });

    testWidgets('dispatches the one-shot GetAnimalsEvent when not yet loaded', (
      tester,
    ) async {
      final bloc = MockAnimalBloc();
      whenListen(
        bloc,
        const Stream<AnimalState>.empty(),
        initialState: AnimalInitial(),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc, herdBloc));

      verify(() => bloc.add(any(that: isA<GetAnimalsEvent>()))).called(1);
      verifyNever(() => bloc.add(any(that: isA<WatchAnimalsEvent>())));
    });
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets('dispatches WatchAnimalsEvent instead of GetAnimalsEvent', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockAnimalBloc();
      whenListen(
        bloc,
        const Stream<AnimalState>.empty(),
        initialState: AnimalInitial(),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc, herdBloc));

      verify(() => bloc.add(any(that: isA<WatchAnimalsEvent>()))).called(1);
      verifyNever(() => bloc.add(any(that: isA<GetAnimalsEvent>())));
    });

    testWidgets('still subscribes when animals are already loaded', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockAnimalBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<AnimalState>.empty(),
        initialState: AnimalLoaded(
          animals: [
            Animal(
              id: 'animal-1',
              userId: 'user-1',
              name: 'Bessie',
              animalTypeId: 'type-1',
              herdId: 'herd-1',
              birthDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc, herdBloc));

      verify(
        () => bloc.add(any(that: isA<WatchAnimalsEvent>())),
      ).called(1);
      verifyNever(() => bloc.add(any(that: isA<GetAnimalsEvent>())));
    });

    // The animal dispatch above was moved onto the watch stream by the
    // first-run fix; the animal-type and herd dispatches below it were left
    // reading once, outside any flag branch. Both blocs are seeded here with
    // an EMPTY loaded list - the state a read that beat the first sync
    // leaves behind - which is exactly when a one-shot read strands the page
    // on an empty picker.
    testWidgets('subscribes to animal types rather than reading once', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockAnimalBloc();
      whenListen(
        bloc,
        const Stream<AnimalState>.empty(),
        initialState: AnimalInitial(),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc, herdBloc));

      verify(
        () => animalTypeBloc.add(any(that: isA<WatchAnimalTypesEvent>())),
      ).called(1);
      verifyNever(
        () => animalTypeBloc.add(any(that: isA<GetAnimalTypesEvent>())),
      );
    });

    testWidgets('subscribes to herds rather than reading once', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockAnimalBloc();
      whenListen(
        bloc,
        const Stream<AnimalState>.empty(),
        initialState: AnimalInitial(),
      );

      await tester.pumpWidget(_wrap(bloc, animalTypeBloc, herdBloc));

      verify(() => herdBloc.add(any(that: isA<WatchHerdsEvent>()))).called(1);
      verifyNever(() => herdBloc.add(any(that: isA<GetHerdsEvent>())));
    });
  });
}
