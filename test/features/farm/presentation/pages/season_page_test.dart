import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/season_page.dart';

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState>
    implements LandBloc {}

class MockPlantBloc extends MockBloc<PlantEvent, PlantState>
    implements PlantBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(GetSeasonsEvent());
    registerFallbackValue(GetLandsEvent());
    registerFallbackValue(GetPlantsEvent());
  });

  testWidgets(
    'Add Season sheet keeps its submit button clear of the system nav bar',
    (tester) async {
      final seasonBloc = MockSeasonBloc();
      final landBloc = MockLandBloc();
      final plantBloc = MockPlantBloc();

      final land = Land(
        id: 'l1',
        userId: 'u1',
        name: 'Field A',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final plant = Plant(
        id: 'p1',
        userId: 'u1',
        name: 'Maize',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      whenListen(
        seasonBloc,
        Stream<SeasonState>.value(const SeasonLoaded(seasons: [])),
        initialState: const SeasonLoaded(seasons: []),
      );
      whenListen(
        landBloc,
        Stream<LandState>.value(LandLoaded(lands: [land])),
        initialState: LandLoaded(lands: [land]),
      );
      whenListen(
        plantBloc,
        Stream<PlantState>.value(PlantLoaded(plants: [plant])),
        initialState: PlantLoaded(plants: [plant]),
      );

      // Simulate a 48px system nav bar with a 1:1 pixel ratio so physical
      // pixels equal logical pixels, keeping the assertion math simple.
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<SeasonBloc>.value(value: seasonBloc),
              BlocProvider<LandBloc>.value(value: landBloc),
              BlocProvider<PlantBloc>.value(value: plantBloc),
            ],
            child: const SeasonPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final buttonBottom = tester
          .getBottomLeft(find.widgetWithText(ElevatedButton, 'Add Season'))
          .dy;
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(
        buttonBottom,
        lessThanOrEqualTo(screenHeight - 48),
        reason: 'Add Season button must clear the 48px system nav bar inset',
      );
    },
  );
}
