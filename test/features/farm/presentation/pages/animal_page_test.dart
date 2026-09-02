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
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_page.dart';

class MockAnimalBloc extends MockBloc<AnimalEvent, AnimalState>
    implements AnimalBloc {}

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockInputBloc extends MockBloc<InputEvent, InputState> implements InputBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState> implements SeasonBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockCostCategoryBloc extends MockBloc<CostCategoryEvent, CostCategoryState>
    implements CostCategoryBloc {}

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
  required InputBloc inputBloc,
  required SeasonBloc seasonBloc,
  required LandBloc landBloc,
  required CostCategoryBloc costCategoryBloc,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<AnimalBloc>.value(value: animalBloc),
      BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
      BlocProvider<HerdBloc>.value(value: herdBloc),
      BlocProvider<InputBloc>.value(value: inputBloc),
      BlocProvider<SeasonBloc>.value(value: seasonBloc),
      BlocProvider<LandBloc>.value(value: landBloc),
      BlocProvider<CostCategoryBloc>.value(value: costCategoryBloc),
    ],
    child: const MaterialApp(
      home: AnimalPage(),
    ),
  );
}

void main() {
  late MockAnimalBloc animalBloc;
  late MockAnimalTypeBloc animalTypeBloc;
  late MockHerdBloc herdBloc;
  late MockInputBloc inputBloc;
  late MockSeasonBloc seasonBloc;
  late MockLandBloc landBloc;
  late MockCostCategoryBloc costCategoryBloc;

  setUp(() {
    animalBloc = MockAnimalBloc();
    animalTypeBloc = MockAnimalTypeBloc();
    herdBloc = MockHerdBloc();
    inputBloc = MockInputBloc();
    seasonBloc = MockSeasonBloc();
    landBloc = MockLandBloc();
    costCategoryBloc = MockCostCategoryBloc();
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
    whenListen(
      inputBloc,
      const Stream<InputState>.empty(),
      initialState: const InputLoaded(inputs: []),
    );
    whenListen(
      seasonBloc,
      const Stream<SeasonState>.empty(),
      initialState: const SeasonLoaded(seasons: []),
    );
    whenListen(
      landBloc,
      const Stream<LandState>.empty(),
      initialState: const LandLoaded(lands: []),
    );
    whenListen(
      costCategoryBloc,
      const Stream<CostCategoryState>.empty(),
      initialState: const CostCategoryLoaded([]),
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
      _harness(
        animalBloc: animalBloc,
        animalTypeBloc: animalTypeBloc,
        herdBloc: herdBloc,
        inputBloc: inputBloc,
        seasonBloc: seasonBloc,
        landBloc: landBloc,
        costCategoryBloc: costCategoryBloc,
      ),
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
      _harness(
        animalBloc: animalBloc,
        animalTypeBloc: animalTypeBloc,
        herdBloc: herdBloc,
        inputBloc: inputBloc,
        seasonBloc: seasonBloc,
        landBloc: landBloc,
        costCategoryBloc: costCategoryBloc,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bessie'), findsOneWidget);
  });

  group('showAddAnimalDialog', () {
    late MockAnimalBloc animalBloc;
    late MockAnimalTypeBloc animalTypeBloc;
    late MockHerdBloc herdBloc;
    late MockInputBloc inputBloc;
    late MockSeasonBloc seasonBloc;
    late MockLandBloc landBloc;
    late MockCostCategoryBloc costCategoryBloc;
    late StreamController<AnimalState> stateController;

    setUpAll(() {
      registerFallbackValue(GetAnimalsEvent());
    });

    setUp(() {
      _mockSecureStorageUserId('user-1');
      animalBloc = MockAnimalBloc();
      animalTypeBloc = MockAnimalTypeBloc();
      herdBloc = MockHerdBloc();
      inputBloc = MockInputBloc();
      seasonBloc = MockSeasonBloc();
      landBloc = MockLandBloc();
      costCategoryBloc = MockCostCategoryBloc();
      whenListen(
        inputBloc,
        const Stream<InputState>.empty(),
        initialState: const InputLoaded(inputs: []),
      );
      whenListen(
        seasonBloc,
        const Stream<SeasonState>.empty(),
        initialState: const SeasonLoaded(seasons: []),
      );
      whenListen(
        landBloc,
        const Stream<LandState>.empty(),
        initialState: const LandLoaded(lands: []),
      );
      whenListen(
        costCategoryBloc,
        const Stream<CostCategoryState>.empty(),
        initialState: const CostCategoryLoaded([]),
      );
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

    // MultiBlocProvider wraps MaterialApp itself, not just its home:
    // content: showAddInputDialog (triggered internally on "Bought") opens
    // a second modal sheet containing CostCategoryTypeSelector, which does
    // its own internal BlocBuilder<CostCategoryBloc, ...> lookup - that
    // sheet is a sibling route within the same Navigator, so it can't see
    // a provider placed only inside home:.
    Widget buildHarness(ValueChanged<Future<String?>> capture) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<AnimalBloc>.value(value: animalBloc),
          BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
          BlocProvider<HerdBloc>.value(value: herdBloc),
          BlocProvider<InputBloc>.value(value: inputBloc),
          BlocProvider<SeasonBloc>.value(value: seasonBloc),
          BlocProvider<LandBloc>.value(value: landBloc),
          BlocProvider<CostCategoryBloc>.value(value: costCategoryBloc),
        ],
        child: MaterialApp(
          home: Builder(
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
      await tester.pumpWidget(buildHarness((_) {}));

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
      await tester.pumpWidget(buildHarness((_) {}));

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

    testWidgets('selecting Bought opens the cost-log prompt after the animal saves', (
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

      // Animal Type and Herd are required/validated fields — per the Global
      // Constraints correction, drive both the inner FormFieldState and the
      // picker's own onChanged, or Form.validate() fails forever and this
      // hangs on the later runAsync(() => resultFuture).
      tester
          .state<FormFieldState<String>>(
            find.descendant(
              of: find.byType(EntityPickerWithAdd<AnimalType>),
              matching: find.byType(DropdownButtonFormField<String>),
            ),
          )
          .didChange('type-1');
      tester
          .widget<EntityPickerWithAdd<AnimalType>>(
            find.byType(EntityPickerWithAdd<AnimalType>),
          )
          .onChanged('type-1');
      await tester.pumpAndSettle();

      tester
          .state<FormFieldState<String>>(
            find.descendant(
              of: find.byType(EntityPickerWithAdd<Herd>),
              matching: find.byType(DropdownButtonFormField<String>),
            ),
          )
          .didChange('herd-1');
      tester
          .widget<EntityPickerWithAdd<Herd>>(find.byType(EntityPickerWithAdd<Herd>))
          .onChanged('herd-1');
      await tester.pumpAndSettle();

      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('animal-acquisition-source-field')),
          )
          .onChanged!('bought');
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
              acquisitionSource: 'bought',
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

      // The cost-log prompt is fire-and-forget from showAddAnimalDialog's
      // own return (see the Global Constraints correction on runAsync +
      // route-pushing deadlocks) — pump once more to let it actually open.
      await tester.pumpAndSettle();

      expect(find.text('Add New Animal Input'), findsOneWidget);
    });
  });

  group('editing an animal', () {
    late MockAnimalBloc animalBloc;
    late MockAnimalTypeBloc animalTypeBloc;
    late MockHerdBloc herdBloc;
    late MockInputBloc inputBloc;
    late MockSeasonBloc seasonBloc;
    late MockLandBloc landBloc;
    late MockCostCategoryBloc costCategoryBloc;
    late Animal existingAnimal;

    setUpAll(() {
      registerFallbackValue(GetAnimalsEvent());
    });

    setUp(() {
      existingAnimal = Animal(
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
      );
      animalBloc = MockAnimalBloc();
      animalTypeBloc = MockAnimalTypeBloc();
      herdBloc = MockHerdBloc();
      inputBloc = MockInputBloc();
      seasonBloc = MockSeasonBloc();
      landBloc = MockLandBloc();
      costCategoryBloc = MockCostCategoryBloc();
      whenListen(
        inputBloc,
        const Stream<InputState>.empty(),
        initialState: const InputLoaded(inputs: []),
      );
      whenListen(
        seasonBloc,
        const Stream<SeasonState>.empty(),
        initialState: const SeasonLoaded(seasons: []),
      );
      whenListen(
        landBloc,
        const Stream<LandState>.empty(),
        initialState: const LandLoaded(lands: []),
      );
      whenListen(
        costCategoryBloc,
        const Stream<CostCategoryState>.empty(),
        initialState: const CostCategoryLoaded([]),
      );
      whenListen(
        animalBloc,
        Stream<AnimalState>.value(AnimalLoaded(animals: [existingAnimal])),
        initialState: AnimalLoaded(animals: [existingAnimal]),
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
        ]),
      );
    });

    testWidgets('shows details, edits sex, and dispatches UpdateAnimalEvent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          animalBloc: animalBloc,
          animalTypeBloc: animalTypeBloc,
          herdBloc: herdBloc,
          inputBloc: inputBloc,
          seasonBloc: seasonBloc,
          landBloc: landBloc,
          costCategoryBloc: costCategoryBloc,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bessie'));
      await tester.pumpAndSettle();

      expect(find.text('Female'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final sexDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('animal-sex-field')),
      );
      sexDropdown.onChanged!('male');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Animal'));
      await tester.pumpAndSettle();

      final captured = verify(() => animalBloc.add(captureAny())).captured;
      final event = captured.whereType<UpdateAnimalEvent>().single;
      expect(event.animal.sex, 'male');
    });

    testWidgets('deletes the animal on confirmation', (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        _harness(
          animalBloc: animalBloc,
          animalTypeBloc: animalTypeBloc,
          herdBloc: herdBloc,
          inputBloc: inputBloc,
          seasonBloc: seasonBloc,
          landBloc: landBloc,
          costCategoryBloc: costCategoryBloc,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bessie'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      verify(() => animalBloc.add(DeleteAnimalEvent('animal-1'))).called(1);
      final deleteHapticCalls = calls.where(
        (c) =>
            c.method == 'HapticFeedback.vibrate' &&
            c.arguments == 'HapticFeedbackType.mediumImpact',
      );
      expect(deleteHapticCalls, hasLength(1));
    });

    testWidgets('opens the cost-log prompt when acquisition source transitions to Bought', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          animalBloc: animalBloc,
          animalTypeBloc: animalTypeBloc,
          herdBloc: herdBloc,
          inputBloc: inputBloc,
          seasonBloc: seasonBloc,
          landBloc: landBloc,
          costCategoryBloc: costCategoryBloc,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bessie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('animal-acquisition-source-field')),
          )
          .onChanged!('bought');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Animal'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Animal Input'), findsOneWidget);
    });

    testWidgets('does not re-prompt when acquisition source was already Bought', (
      tester,
    ) async {
      existingAnimal = Animal(
        id: 'animal-1',
        userId: 'user-1',
        name: 'Bessie',
        animalTypeId: 'type-1',
        herdId: 'herd-1',
        birthDate: now,
        sex: 'female',
        acquisitionSource: 'bought',
        createdAt: now,
        updatedAt: now,
      );
      whenListen(
        animalBloc,
        Stream<AnimalState>.value(AnimalLoaded(animals: [existingAnimal])),
        initialState: AnimalLoaded(animals: [existingAnimal]),
      );

      await tester.pumpWidget(
        _harness(
          animalBloc: animalBloc,
          animalTypeBloc: animalTypeBloc,
          herdBloc: herdBloc,
          inputBloc: inputBloc,
          seasonBloc: seasonBloc,
          landBloc: landBloc,
          costCategoryBloc: costCategoryBloc,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bessie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Animal'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Animal Input'), findsNothing);
    });
  });
}
