import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/plant_page.dart';

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
  group('showAddPlantDialog', () {
    late MockPlantBloc plantBloc;
    late StreamController<PlantState> stateController;

    setUp(() {
      _mockSecureStorageUserId('user-1');
      plantBloc = MockPlantBloc();
      stateController = StreamController<PlantState>.broadcast();
      whenListen(
        plantBloc,
        stateController.stream,
        initialState: const PlantLoaded(plants: []),
      );
    });

    tearDown(() => stateController.close());

    Widget buildHarness(ValueChanged<Future<String?>> capture) {
      return MaterialApp(
        home: BlocProvider<PlantBloc>.value(
          value: plantBloc,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => capture(showAddPlantDialog(context)),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'returns the new plant id once the bloc reports it added',
      (tester) async {
        late Future<String?> resultFuture;
        await tester.pumpWidget(
          buildHarness((future) => resultFuture = future),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Plant Name *'),
          'Maize',
        );

        final now = DateTime.now();
        stateController.add(
          PlantLoaded(
            plants: [
              Plant(
                id: 'plant-1',
                userId: 'user-1',
                name: 'Maize',
                createdAt: now,
                updatedAt: now,
              ),
            ],
            successMessage: 'Crop added',
          ),
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Plant'));
        await tester.pumpAndSettle();

        final result = await tester.runAsync(() => resultFuture);
        expect(result, 'plant-1');
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
