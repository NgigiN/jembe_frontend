import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_type_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

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
  group('showAddAnimalTypeDialog', () {
    late MockAnimalTypeBloc animalTypeBloc;
    late StreamController<AnimalTypeState> stateController;

    setUp(() {
      _mockSecureStorageUserId('user-1');
      animalTypeBloc = MockAnimalTypeBloc();
      stateController = StreamController<AnimalTypeState>.broadcast();
      whenListen(
        animalTypeBloc,
        stateController.stream,
        initialState: const AnimalTypeLoaded([]),
      );
    });

    tearDown(() => stateController.close());

    Widget buildHarness(ValueChanged<Future<String?>> capture) {
      return MaterialApp(
        home: BlocProvider<AnimalTypeBloc>.value(
          value: animalTypeBloc,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => capture(showAddAnimalTypeDialog(context)),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'returns the new animal type id once the bloc reports it added',
      (tester) async {
        late Future<String?> resultFuture;
        await tester.pumpWidget(
          buildHarness((future) => resultFuture = future),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Animal Type Name *'),
          'Cow',
        );

        final now = DateTime.now();
        stateController.add(
          AnimalTypeLoaded(
            [
              AnimalType(
                id: 'type-1',
                userId: 'user-1',
                name: 'Cow',
                createdAt: now,
                updatedAt: now,
              ),
            ],
            successMessage: 'Animal type added',
          ),
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Animal Type'));
        await tester.pumpAndSettle();

        final result = await tester.runAsync(() => resultFuture);
        expect(result, 'type-1');
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
