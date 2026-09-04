import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/widgets/crud/cost_category_type_selector.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
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
import 'package:farm_tracker/features/farm/presentation/pages/input_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInputBloc extends MockBloc<InputEvent, InputState> implements InputBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState> implements SeasonBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockCostCategoryBloc extends MockBloc<CostCategoryEvent, CostCategoryState>
    implements CostCategoryBloc {}

void main() {
  late MockInputBloc inputBloc;
  late MockHerdBloc herdBloc;
  late MockSeasonBloc seasonBloc;
  late MockLandBloc landBloc;
  late MockCostCategoryBloc costCategoryBloc;
  late StreamController<InputState> inputStateController;
  final now = DateTime.now();

  setUpAll(() {
    registerFallbackValue(GetInputsEvent());
  });

  setUp(() {
    inputBloc = MockInputBloc();
    herdBloc = MockHerdBloc();
    seasonBloc = MockSeasonBloc();
    landBloc = MockLandBloc();
    costCategoryBloc = MockCostCategoryBloc();
    inputStateController = StreamController<InputState>.broadcast();
    whenListen(
      inputBloc,
      inputStateController.stream,
      initialState: const InputLoaded(inputs: []),
    );
    whenListen(
      herdBloc,
      Stream<HerdState>.value(
        HerdLoaded([
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
      ),
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

  tearDown(() => inputStateController.close());

  // MultiBlocProvider wraps MaterialApp itself (matching main.dart's real
  // wiring), not just its `home:` content: showModalBottomSheet pushes a
  // new route as a sibling within the same Navigator, so a provider placed
  // only inside `home:` isn't an ancestor of that route's own build
  // context. CostCategoryTypeSelector does its own internal
  // BlocBuilder<CostCategoryBloc, ...> lookup from inside the sheet, so it
  // needs the provider to sit above the Navigator, not below it.
  Widget harness(ValueChanged<BuildContext> captureContext) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<InputBloc>.value(value: inputBloc),
        BlocProvider<HerdBloc>.value(value: herdBloc),
        BlocProvider<SeasonBloc>.value(value: seasonBloc),
        BlocProvider<LandBloc>.value(value: landBloc),
        BlocProvider<CostCategoryBloc>.value(value: costCategoryBloc),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            captureContext(context);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
  }

  testWidgets(
    'unlocked: shows the herd picker and dispatches AddInputEvent with the chosen herd',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(harness((context) => capturedContext = context));

      unawaited(showAddInputDialog(capturedContext, sourceType: 'animal'));
      await tester.pumpAndSettle();

      expect(find.text('Select Herd *'), findsOneWidget);

      // Select Herd is a required/validated field: drive the inner
      // FormFieldState too, or Form.validate() fails silently and "Add
      // Input" never submits (same pitfall documented in the Animal plan's
      // Global Constraints).
      final herdDropdownFinder = find.ancestor(
        of: find.text('Select Herd *'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      tester.state<FormFieldState<String>>(herdDropdownFinder).didChange('herd-1');
      tester.widget<DropdownButtonFormField<String>>(herdDropdownFinder).onChanged!('herd-1');
      await tester.pumpAndSettle();

      // CostCategoryTypeSelector.onTypeChanged is also a plain callback
      // prop wrapping a *required* inner DropdownButtonFormField — same
      // dual-drive requirement as the herd field above.
      final typeSelector = tester.widget<CostCategoryTypeSelector>(
        find.byType(CostCategoryTypeSelector),
      );
      final typeDropdownFinder = find.ancestor(
        of: find.text('Input Type *'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      tester.state<FormFieldState<String>>(typeDropdownFinder).didChange('Feed');
      typeSelector.onTypeChanged('Feed');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cost *'),
        '500',
      );

      // The sheet now awaits the bloc's terminal state before it confirms
      // and closes (P3-06), so the confirming state must be emitted after
      // the submit is tapped, not before.
      await tester.tap(find.text('Add Input'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      inputStateController.add(
        const InputLoaded(inputs: [], successMessage: 'Input added'),
      );
      await tester.pumpAndSettle();

      final captured = verify(() => inputBloc.add(captureAny())).captured;
      final event = captured.whereType<AddInputEvent>().single;
      expect(event.input.sourceType, 'animal');
      expect(event.input.animalId, isNull);
    },
  );

  testWidgets(
    'locked: hides the herd picker and pre-sets sourceId/animalId from the locks',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(harness((context) => capturedContext = context));

      unawaited(
        showAddInputDialog(
          capturedContext,
          sourceType: 'animal',
          lockedHerdId: 'herd-1',
          lockedAnimalId: 42,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Herd *'), findsNothing);

      final typeSelector = tester.widget<CostCategoryTypeSelector>(
        find.byType(CostCategoryTypeSelector),
      );
      final typeDropdownFinder = find.ancestor(
        of: find.text('Input Type *'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      tester.state<FormFieldState<String>>(typeDropdownFinder).didChange('Purchase');
      typeSelector.onTypeChanged('Purchase');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cost *'),
        '15000',
      );

      // The sheet now awaits the bloc's terminal state before it confirms
      // and closes (P3-06), so the confirming state must be emitted after
      // the submit is tapped, not before.
      await tester.tap(find.text('Add Input'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      inputStateController.add(
        const InputLoaded(inputs: [], successMessage: 'Input added'),
      );
      await tester.pumpAndSettle();

      final captured = verify(() => inputBloc.add(captureAny())).captured;
      final event = captured.whereType<AddInputEvent>().single;
      expect(event.input.sourceType, 'animal');
      expect(event.input.sourceId, 'herd-1');
      expect(event.input.animalId, 42);
    },
  );
}
