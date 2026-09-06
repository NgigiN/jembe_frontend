// Mirrors `land_page_refetch_test.dart`'s "fetches when not yet loaded"
// shape, extended with the `OfflineConfig.enabled` gate added in Task 6's
// fix round 1: `PlantPage.initState` must dispatch `WatchPlantsEvent` when
// the offline flag is on, and the legacy one-shot `GetPlantsEvent` when it
// is off — never both, never neither.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/plant_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPlantBloc extends MockBloc<PlantEvent, PlantState>
    implements PlantBloc {}

Widget _wrap(PlantBloc bloc) {
  return MaterialApp(
    home: BlocProvider<PlantBloc>.value(value: bloc, child: const PlantPage()),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(GetPlantsEvent());
    registerFallbackValue(WatchPlantsEvent());
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    testWidgets('does not refetch when plants already loaded', (
      tester,
    ) async {
      final bloc = MockPlantBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<PlantState>.empty(),
        initialState: PlantLoaded(
          plants: [
            Plant(
              id: 'plant-1',
              userId: 'user-1',
              name: 'Maize',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      await tester.pumpWidget(_wrap(bloc));

      verifyNever(() => bloc.add(any(that: isA<GetPlantsEvent>())));
      verifyNever(() => bloc.add(any(that: isA<WatchPlantsEvent>())));
    });

    testWidgets('dispatches the one-shot GetPlantsEvent when not yet loaded', (
      tester,
    ) async {
      final bloc = MockPlantBloc();
      whenListen(
        bloc,
        const Stream<PlantState>.empty(),
        initialState: PlantInitial(),
      );

      await tester.pumpWidget(_wrap(bloc));

      verify(() => bloc.add(any(that: isA<GetPlantsEvent>()))).called(1);
      verifyNever(() => bloc.add(any(that: isA<WatchPlantsEvent>())));
    });
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets('dispatches WatchPlantsEvent instead of GetPlantsEvent', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockPlantBloc();
      whenListen(
        bloc,
        const Stream<PlantState>.empty(),
        initialState: PlantInitial(),
      );

      await tester.pumpWidget(_wrap(bloc));

      verify(() => bloc.add(any(that: isA<WatchPlantsEvent>()))).called(1);
      verifyNever(() => bloc.add(any(that: isA<GetPlantsEvent>())));
    });

    testWidgets('does not re-watch when plants already loaded', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockPlantBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<PlantState>.empty(),
        initialState: PlantLoaded(
          plants: [
            Plant(
              id: 'plant-1',
              userId: 'user-1',
              name: 'Maize',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      await tester.pumpWidget(_wrap(bloc));

      verifyNever(() => bloc.add(any(that: isA<WatchPlantsEvent>())));
      verifyNever(() => bloc.add(any(that: isA<GetPlantsEvent>())));
    });
  });
}
