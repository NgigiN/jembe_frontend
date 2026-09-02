import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:farm_tracker/core/audio/sound_service.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
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
import 'package:farm_tracker/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class _FakeSoundPlayer implements SoundPlayer {
  final calls = <String>[];

  @override
  Future<void> play(String assetPath) async => calls.add(assetPath);
}

class MockLandBloc extends MockBloc<LandEvent, LandState>
    implements LandBloc {}

class MockPlantBloc extends MockBloc<PlantEvent, PlantState>
    implements PlantBloc {}

void _mockSecureStorageUserId(String userId) {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'read') return userId;
    if (call.method == 'readAll') return <String, String>{};
    return null;
  });
}

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

  group('showAddSeasonDialog', () {
    late MockSeasonBloc seasonBloc;
    late MockLandBloc landBloc;
    late MockPlantBloc plantBloc;
    late StreamController<SeasonState> stateController;
    late _FakeSoundPlayer soundPlayer;
    final platformCalls = <MethodCall>[];
    final now = DateTime.now();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      _mockSecureStorageUserId('user-1');
      seasonBloc = MockSeasonBloc();
      landBloc = MockLandBloc();
      plantBloc = MockPlantBloc();
      stateController = StreamController<SeasonState>.broadcast();
      whenListen(
        seasonBloc,
        stateController.stream,
        initialState: const SeasonLoaded(seasons: []),
      );
      whenListen(
        landBloc,
        Stream<LandState>.empty(),
        initialState: LandLoaded(
          lands: [
            Land(
              id: 'land-1',
              userId: 'user-1',
              name: 'North Field',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );
      whenListen(
        plantBloc,
        Stream<PlantState>.empty(),
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
      platformCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call);
        return null;
      });
      soundPlayer = _FakeSoundPlayer();
      sl.registerLazySingleton<SoundService>(
        () => SoundService(player: soundPlayer),
      );
    });

    tearDown(() {
      stateController.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      sl.unregister<SoundService>();
    });

    Widget buildHarness(ValueChanged<Future<String?>> capture) {
      return MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SeasonBloc>.value(value: seasonBloc),
            BlocProvider<LandBloc>.value(value: landBloc),
            BlocProvider<PlantBloc>.value(value: plantBloc),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => capture(showAddSeasonDialog(context)),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'returns the new season id once the bloc reports it created',
      (tester) async {
        late Future<String?> resultFuture;
        await tester.pumpWidget(
          buildHarness((future) => resultFuture = future),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Season Name *'),
          'Long Rains 2026',
        );

        final dropdowns = find.byType(DropdownButtonFormField<String>);
        await tester.tap(dropdowns.at(0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Maize').last);
        await tester.pumpAndSettle();

        await tester.tap(dropdowns.at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('North Field').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Start Date *'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start Date *'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        stateController.add(
          SeasonLoaded(
            seasons: [
              Season(
                id: 'season-1',
                userId: 'user-1',
                name: 'Long Rains 2026',
                plantId: 'plant-1',
                landId: 'land-1',
                startDate: now,
                createdAt: now,
                updatedAt: now,
              ),
            ],
            successMessage: 'Season created',
          ),
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Season'));
        await tester.pumpAndSettle();

        final result = await tester.runAsync(() => resultFuture);
        expect(result, 'season-1');

        final hapticCalls = platformCalls.where(
          (c) => c.method == 'HapticFeedback.vibrate',
        );
        expect(hapticCalls, hasLength(1));
        expect(
          hapticCalls.single.arguments,
          'HapticFeedbackType.lightImpact',
        );
        expect(soundPlayer.calls, ['sounds/success.mp3']);
      },
    );

    testWidgets(
      'returns null when the sheet is closed without submitting',
      (tester) async {
        late Future<String?> resultFuture;
        await tester.pumpWidget(
          buildHarness((future) => resultFuture = future),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        final result = await tester.runAsync(() => resultFuture);
        expect(result, isNull);
      },
    );
  });
}
