import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:farm_tracker/core/widgets/crud/entity_picker_with_add.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
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

class MockAnimalBloc extends MockBloc<AnimalEvent, AnimalState>
    implements AnimalBloc {}

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

final now = DateTime.now();

/// Stubs the flutter_secure_storage platform channel so
/// UserUtils.getCurrentUserId() resolves without touching real native code.
void _mockSecureStorageUserId(String userId) {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'read') return userId;
    if (call.method == 'readAll') return <String, String>{};
    return null;
  });
}

Widget _harness({
  required AnimalBloc animalBloc,
  required AnimalTypeBloc animalTypeBloc,
  required HerdBloc herdBloc,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AnimalBloc>.value(value: animalBloc),
        BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
        BlocProvider<HerdBloc>.value(value: herdBloc),
      ],
      child: const AnimalPage(),
    ),
  );
}

void main() {
  late MockAnimalBloc animalBloc;
  late MockAnimalTypeBloc animalTypeBloc;
  late MockHerdBloc herdBloc;

  setUp(() {
    animalBloc = MockAnimalBloc();
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

  testWidgets('shows a skeleton (not a spinner) while animals are loading', (
    tester,
  ) async {
    whenListen(
      animalBloc,
      Stream<AnimalState>.value(const AnimalLoading()),
      initialState: const AnimalLoading(),
    );

    await tester.pumpWidget(
      _harness(animalBloc: animalBloc, animalTypeBloc: animalTypeBloc, herdBloc: herdBloc),
    );

    final skeletonizerFinder = find.byWidgetPredicate(
      (widget) => widget is Skeletonizer,
    );
    expect(skeletonizerFinder, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders one card per loaded animal', (tester) async {
    final animal = Animal(
      id: 'animal-1',
      userId: 'user-1',
      name: 'Bessie',
      animalTypeId: 'type-1',
      herdId: 'herd-1',
      birthDate: now,
      createdAt: now,
      updatedAt: now,
    );
    whenListen(
      animalBloc,
      Stream<AnimalState>.value(AnimalLoaded(animals: [animal])),
      initialState: AnimalLoaded(animals: [animal]),
    );

    await tester.pumpWidget(
      _harness(animalBloc: animalBloc, animalTypeBloc: animalTypeBloc, herdBloc: herdBloc),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bessie'), findsOneWidget);
  });

  group('showAddAnimalDialog', () {
    late MockAnimalBloc animalBloc;
    late MockAnimalTypeBloc animalTypeBloc;
    late MockHerdBloc herdBloc;
    late StreamController<AnimalState> stateController;

    setUpAll(() {
      registerFallbackValue(GetAnimalsEvent());
    });

    setUp(() {
      _mockSecureStorageUserId('user-1');
      animalBloc = MockAnimalBloc();
      animalTypeBloc = MockAnimalTypeBloc();
      herdBloc = MockHerdBloc();
      stateController = StreamController<AnimalState>.broadcast();
      whenListen(
        animalBloc,
        stateController.stream,
        initialState: const AnimalLoaded(animals: []),
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
          AnimalType(
            id: 'type-2',
            userId: 'user-1',
            name: 'Goat',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
      whenListen(
        herdBloc,
        const Stream<HerdState>.empty(),
        initialState: HerdLoaded([
          Herd(
            id: 'herd-1',
            userId: 'user-1',
            name: 'Cow Herd',
            animalTypeId: 'type-1',
            location: 'North Field',
            initialHeadCount: 5,
            currentHeadCount: 5,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
          Herd(
            id: 'herd-2',
            userId: 'user-1',
            name: 'Goat Herd',
            animalTypeId: 'type-2',
            location: 'South Field',
            initialHeadCount: 3,
            currentHeadCount: 3,
            startDate: now,
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
            BlocProvider<AnimalBloc>.value(value: animalBloc),
            BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
            BlocProvider<HerdBloc>.value(value: herdBloc),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => capture(showAddAnimalDialog(context)),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets('submits name, type, herd, sex, and acquisition source on the dispatched AddAnimalEvent', (
      tester,
    ) async {
      late Future<String?> resultFuture;
      await tester.pumpWidget(buildHarness((future) => resultFuture = future));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        'Bessie',
      );

      // EntityPickerWithAdd.onChanged is a plain callback prop: invoking it
      // directly updates the outer closure variable but never touches the
      // inner DropdownButtonFormField's own FormFieldState, which is what
      // Form.validate() actually checks for a *required* field. Drive the
      // FormFieldState directly too, or validation silently fails forever
      // and the sheet never closes.
      final typePicker = tester.widget<EntityPickerWithAdd<AnimalType>>(
        find.byType(EntityPickerWithAdd<AnimalType>),
      );
      tester
          .state<FormFieldState<String>>(
            find.descendant(
              of: find.byType(EntityPickerWithAdd<AnimalType>),
              matching: find.byType(DropdownButtonFormField<String>),
            ),
          )
          .didChange('type-1');
      typePicker.onChanged('type-1');
      await tester.pumpAndSettle();

      final herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      tester
          .state<FormFieldState<String>>(
            find.descendant(
              of: find.byType(EntityPickerWithAdd<Herd>),
              matching: find.byType(DropdownButtonFormField<String>),
            ),
          )
          .didChange('herd-1');
      herdPicker.onChanged('herd-1');
      await tester.pumpAndSettle();

      final sexDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('animal-sex-field')),
      );
      sexDropdown.onChanged!('female');
      await tester.pumpAndSettle();

      final acquisitionDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('animal-acquisition-source-field')),
      );
      acquisitionDropdown.onChanged!('bredOnFarm');
      await tester.pumpAndSettle();

      stateController.add(
        AnimalLoaded(
          animals: [
            Animal(
              id: 'animal-1',
              userId: 'user-1',
              name: 'Bessie',
              animalTypeId: 'type-1',
              herdId: 'herd-1',
              birthDate: now,
              sex: 'female',
              acquisitionSource: 'bredOnFarm',
              createdAt: now,
              updatedAt: now,
            ),
          ],
          successMessage: 'Animal added',
        ),
      );

      await tester.tap(find.text('Add Animal'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => resultFuture);

      final captured = verify(() => animalBloc.add(captureAny())).captured;
      final event = captured.whereType<AddAnimalEvent>().single;
      expect(event.animal.name, 'Bessie');
      expect(event.animal.animalTypeId, 'type-1');
      expect(event.animal.herdId, 'herd-1');
      expect(event.animal.sex, 'female');
      expect(event.animal.acquisitionSource, 'bredOnFarm');
    });

    testWidgets('herd picker only shows herds matching the selected animal type', (
      tester,
    ) async {
      late Future<String?> resultFuture;
      await tester.pumpWidget(buildHarness((future) => resultFuture = future));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final typePicker = tester.widget<EntityPickerWithAdd<AnimalType>>(
        find.byType(EntityPickerWithAdd<AnimalType>),
      );
      typePicker.onChanged('type-1');
      await tester.pumpAndSettle();

      var herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      expect(herdPicker.items.map((h) => h.id), ['herd-1']);

      typePicker.onChanged('type-2');
      await tester.pumpAndSettle();

      herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      expect(herdPicker.items.map((h) => h.id), ['herd-2']);
    });

    testWidgets('changing animal type clears a now-invalid herd selection', (
      tester,
    ) async {
      late Future<String?> resultFuture;
      await tester.pumpWidget(buildHarness((future) => resultFuture = future));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final typePicker = tester.widget<EntityPickerWithAdd<AnimalType>>(
        find.byType(EntityPickerWithAdd<AnimalType>),
      );
      typePicker.onChanged('type-1');
      await tester.pumpAndSettle();

      var herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      herdPicker.onChanged('herd-1');
      await tester.pumpAndSettle();

      typePicker.onChanged('type-2');
      await tester.pumpAndSettle();

      herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      expect(herdPicker.selectedId, isNull);
    });
  });
}
