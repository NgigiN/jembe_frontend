// Mirrors `plant_page_initstate_test.dart`'s shape:
// `AnimalTypePage.initState` must dispatch `WatchAnimalTypesEvent` when the
// offline flag is on, and the legacy one-shot `GetAnimalTypesEvent` when it
// is off — never both, never neither.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_type_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

Widget _wrap(AnimalTypeBloc bloc) {
  return MaterialApp(
    home: BlocProvider<AnimalTypeBloc>.value(
      value: bloc,
      child: const AnimalTypePage(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(GetAnimalTypesEvent());
    registerFallbackValue(WatchAnimalTypesEvent());
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    testWidgets('does not refetch when animal types already loaded', (
      tester,
    ) async {
      final bloc = MockAnimalTypeBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<AnimalTypeState>.empty(),
        initialState: AnimalTypeLoaded([
          AnimalType(
            id: 'type-1',
            userId: 'user-1',
            name: 'Cattle',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await tester.pumpWidget(_wrap(bloc));

      verifyNever(() => bloc.add(any(that: isA<GetAnimalTypesEvent>())));
      verifyNever(() => bloc.add(any(that: isA<WatchAnimalTypesEvent>())));
    });

    testWidgets(
      'dispatches the one-shot GetAnimalTypesEvent when not yet loaded',
      (tester) async {
        final bloc = MockAnimalTypeBloc();
        whenListen(
          bloc,
          const Stream<AnimalTypeState>.empty(),
          initialState: AnimalTypeInitial(),
        );

        await tester.pumpWidget(_wrap(bloc));

        verify(() => bloc.add(any(that: isA<GetAnimalTypesEvent>()))).called(1);
        verifyNever(() => bloc.add(any(that: isA<WatchAnimalTypesEvent>())));
      },
    );
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets(
      'dispatches WatchAnimalTypesEvent instead of GetAnimalTypesEvent',
      (tester) async {
        OfflineConfig.enabled = true;
        final bloc = MockAnimalTypeBloc();
        whenListen(
          bloc,
          const Stream<AnimalTypeState>.empty(),
          initialState: AnimalTypeInitial(),
        );

        await tester.pumpWidget(_wrap(bloc));

        verify(
          () => bloc.add(any(that: isA<WatchAnimalTypesEvent>())),
        ).called(1);
        verifyNever(() => bloc.add(any(that: isA<GetAnimalTypesEvent>())));
      },
    );

    testWidgets('does not re-watch when animal types already loaded', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockAnimalTypeBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<AnimalTypeState>.empty(),
        initialState: AnimalTypeLoaded([
          AnimalType(
            id: 'type-1',
            userId: 'user-1',
            name: 'Cattle',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await tester.pumpWidget(_wrap(bloc));

      verifyNever(() => bloc.add(any(that: isA<WatchAnimalTypesEvent>())));
      verifyNever(() => bloc.add(any(that: isA<GetAnimalTypesEvent>())));
    });
  });
}
