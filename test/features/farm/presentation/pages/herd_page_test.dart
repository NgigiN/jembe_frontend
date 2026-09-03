import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/herd_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

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
  group('showAddHerdDialog', () {
    late MockHerdBloc herdBloc;
    late MockAnimalTypeBloc animalTypeBloc;
    late StreamController<HerdState> stateController;
    final now = DateTime.now();

    setUp(() {
      _mockSecureStorageUserId('user-1');
      herdBloc = MockHerdBloc();
      animalTypeBloc = MockAnimalTypeBloc();
      stateController = StreamController<HerdState>.broadcast();
      whenListen(
        herdBloc,
        stateController.stream,
        initialState: const HerdLoaded([]),
      );
      whenListen(
        animalTypeBloc,
        const Stream<AnimalTypeState>.empty(),
        initialState: AnimalTypeLoaded([
          AnimalType(
            id: 'type-1',
            userId: 'user-1',
            name: 'Cow',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
    });

    tearDown(() => stateController.close());

    Widget buildHarness(ValueChanged<Future<String?>> capture) {
      return MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<HerdBloc>.value(value: herdBloc),
            BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => capture(showAddHerdDialog(context)),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'returns the new herd id once the bloc reports it created',
      (tester) async {
        late Future<String?> resultFuture;
        await tester.pumpWidget(
          buildHarness((future) => resultFuture = future),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Herd Name *'),
          'Main Herd',
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cow').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Location *'),
          'North Field',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Initial Head Count *'),
          '10',
        );
        await tester.ensureVisible(find.text('Start Date *'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start Date *'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        stateController.add(
          HerdLoaded(
            [
              Herd(
                id: 'herd-1',
                userId: 'user-1',
                name: 'Main Herd',
                animalTypeId: 'type-1',
                location: 'North Field',
                initialHeadCount: 10,
                currentHeadCount: 10,
                startDate: now,
                createdAt: now,
                updatedAt: now,
              ),
            ],
            successMessage: 'Herd created',
          ),
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Register Herd'));
        await tester.pumpAndSettle();

        final result = await tester.runAsync(() => resultFuture);
        expect(result, 'herd-1');
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
