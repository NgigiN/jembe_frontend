# Safe-Area Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the "Add Season" and "Save Revenue" buttons from sitting behind the 3-button Android system navigation bar.

**Architecture:** Two independent, unrelated-file fixes. `season_page.dart` hand-rolled its own bottom sheet instead of using the shared `EntityFormSheet` helper (which already handles this correctly) - migrate it to match every other CRUD page. `revenue_page.dart`'s `AddRevenuePage` is a full page, not a sheet, whose scroll padding never accounted for the system inset - give it the padding it's missing using the extension that already exists for this.

**Tech Stack:** Flutter, flutter_bloc, mocktail/bloc_test for widget tests, `flutter_test`'s `TestFlutterView.padding`/`FakeViewPadding` to simulate a system nav bar in tests.

## Global Constraints

- No new dependencies.
- Follow the existing `EntityFormSheet` / `sheetContext` naming convention used in `herd_page.dart` and `activity_page.dart` exactly - don't invent a new pattern.
- Every widget test that simulates a system inset must reset it via `addTearDown` (`tester.view.resetPadding`, `tester.view.resetDevicePixelRatio`) so it doesn't leak into later tests in the same run.

---

### Task 1: Migrate `season_page.dart`'s bottom sheets to `EntityFormSheet`

**Files:**
- Modify: `lib/features/farm/presentation/pages/season_page.dart`
- Test: `test/features/farm/presentation/pages/season_page_test.dart` (new)

**Interfaces:**
- Consumes: `EntityFormSheet.container({required BuildContext context, required Widget child, double heightFactor = 0.8})` and `EntityFormSheet.scrollableForm({required BuildContext context, required Widget child})`, both already defined in `lib/core/widgets/crud/entity_form_sheet.dart` - no changes needed there.
- Produces: nothing consumed by other tasks in this plan.

- [ ] **Step 1: Write the failing test**

Create `test/features/farm/presentation/pages/season_page_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/season_page_test.dart`
Expected: FAIL - `buttonBottom` is within ~20px of the raw screen height (the hand-rolled sheet only pads by the fixed `EdgeInsets.all(20)`, not the 48px system inset), so it is NOT `lessThanOrEqualTo(screenHeight - 48)`.

- [ ] **Step 3: Migrate the Add Season sheet**

In `lib/features/farm/presentation/pages/season_page.dart`, add the import:

```dart
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
```

Replace the entire `_showAddSeasonDialog` method body's `showModalBottomSheet(...)` call (currently building a raw `Container` with manual `BoxDecoration`/`Padding`) with:

```dart
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntityFormSheet.container(
          context: sheetContext,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add New Season',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: EntityFormSheet.scrollableForm(
                    context: sheetContext,
                    child: Form(
                      key: formKey,
                      child: _seasonFormFields(
                        context: sheetContext,
                        nameController: nameController,
                        plants: plants,
                        lands: lands,
                        selectedPlantId: selectedPlantId,
                        selectedLandId: selectedLandId,
                        selectedStartDate: selectedStartDate,
                        selectedEndDate: selectedEndDate,
                        onPlantChanged: (value) =>
                            setSheetState(() => selectedPlantId = value),
                        onLandChanged: (value) =>
                            setSheetState(() => selectedLandId = value),
                        onStartDateChanged: (value) =>
                            setSheetState(() => selectedStartDate = value),
                        onEndDateChanged: (value) =>
                            setSheetState(() => selectedEndDate = value),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }

                      final userId = await UserUtils.getCurrentUserId();
                      if (userId == null) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('User not authenticated'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final season = SeasonModel.create(
                        userId: userId,
                        name: sanitizeText(nameController.text),
                        plantId: selectedPlantId!,
                        landId: selectedLandId!,
                        startDate: selectedStartDate!,
                        endDate: selectedEndDate,
                      );
                      context.read<SeasonBloc>().add(AddSeasonEvent(season));
                      Navigator.pop(sheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Add Season',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/season_page_test.dart`
Expected: PASS

- [ ] **Step 5: Migrate the Edit Season sheet the same way**

Replace `_showEditSeasonDialog`'s `showModalBottomSheet(...)` call the same way - `useSafeArea: true`, wrap in `EntityFormSheet.container`/`EntityFormSheet.scrollableForm`, rename the builder context to `sheetContext`, and pass `context: sheetContext` into `_seasonFormFields`:

```dart
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntityFormSheet.container(
          context: sheetContext,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Season',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: EntityFormSheet.scrollableForm(
                    context: sheetContext,
                    child: Form(
                      key: formKey,
                      child: _seasonFormFields(
                        context: sheetContext,
                        nameController: nameController,
                        plants: plants,
                        lands: lands,
                        selectedPlantId: selectedPlantId,
                        selectedLandId: selectedLandId,
                        selectedStartDate: selectedStartDate,
                        selectedEndDate: selectedEndDate,
                        onPlantChanged: (value) =>
                            setSheetState(() => selectedPlantId = value),
                        onLandChanged: (value) =>
                            setSheetState(() => selectedLandId = value),
                        onStartDateChanged: (value) =>
                            setSheetState(() => selectedStartDate = value),
                        onEndDateChanged: (value) =>
                            setSheetState(() => selectedEndDate = value),
                        showClearEndDate: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }

                      final updatedSeason = SeasonModel(
                        id: season.id,
                        userId: season.userId,
                        name: sanitizeText(nameController.text),
                        plantId: selectedPlantId!,
                        landId: selectedLandId!,
                        startDate: selectedStartDate!,
                        endDate: selectedEndDate,
                        createdAt: season.createdAt,
                        updatedAt: DateTime.now(),
                      );
                      context.read<SeasonBloc>().add(
                        UpdateSeasonEvent(updatedSeason),
                      );
                      Navigator.pop(sheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(sheetContext).colorScheme.primary,
                      foregroundColor: Theme.of(sheetContext).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Update Season',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
```

- [ ] **Step 6: Run the full test file and `flutter analyze` on the changed file**

Run: `flutter test test/features/farm/presentation/pages/season_page_test.dart`
Expected: PASS

Run: `flutter analyze lib/features/farm/presentation/pages/season_page.dart`
Expected: no new issues beyond what already exists in the file

- [ ] **Step 7: Commit**

```bash
git add lib/features/farm/presentation/pages/season_page.dart test/features/farm/presentation/pages/season_page_test.dart
git commit -m "fix Add/Edit Season sheets sitting behind the system nav bar

Migrated both hand-rolled showModalBottomSheet calls to the shared
EntityFormSheet helper (useSafeArea + systemBottomInset padding),
matching every other CRUD page's bottom sheet."
```

---

### Task 2: Give `AddRevenuePage` bottom safe-area padding

**Files:**
- Modify: `lib/features/farm/presentation/pages/revenue_page.dart`
- Test: `test/features/farm/presentation/pages/add_revenue_page_test.dart` (new)

**Interfaces:**
- Consumes: `context.systemBottomInset` (already defined as an extension getter on `BuildContext` in `lib/core/utils/safe_layout_utils.dart`, already imported in `revenue_page.dart`).
- Produces: nothing consumed by other tasks in this plan.

- [ ] **Step 1: Write the failing test**

Create `test/features/farm/presentation/pages/add_revenue_page_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/revenue_page.dart';

class MockRevenueBloc extends MockBloc<RevenueEvent, RevenueState>
    implements RevenueBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState>
    implements HerdBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(GetSeasonsEvent());
    registerFallbackValue(GetHerdsEvent());
  });

  testWidgets(
    'Add Revenue page keeps its Save button clear of the system nav bar',
    (tester) async {
      final revenueBloc = MockRevenueBloc();
      final seasonBloc = MockSeasonBloc();
      final herdBloc = MockHerdBloc();

      whenListen(
        revenueBloc,
        Stream<RevenueState>.value(RevenueInitial()),
        initialState: RevenueInitial(),
      );
      whenListen(
        seasonBloc,
        Stream<SeasonState>.value(const SeasonLoaded(seasons: [])),
        initialState: const SeasonLoaded(seasons: []),
      );
      whenListen(
        herdBloc,
        Stream<HerdState>.value(const HerdLoaded([])),
        initialState: const HerdLoaded([]),
      );

      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<RevenueBloc>.value(value: revenueBloc),
              BlocProvider<SeasonBloc>.value(value: seasonBloc),
              BlocProvider<HerdBloc>.value(value: herdBloc),
            ],
            child: const AddRevenuePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The form is taller than the test viewport, so scroll to the very
      // bottom before measuring the Save button's position.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();

      final buttonBottom = tester
          .getBottomLeft(find.widgetWithText(FilledButton, 'Save Revenue'))
          .dy;
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(
        buttonBottom,
        lessThanOrEqualTo(screenHeight - 48),
        reason: 'Save Revenue button must clear the 48px system nav bar inset',
      );
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/add_revenue_page_test.dart`
Expected: FAIL - the scroll view's padding is a flat `EdgeInsets.all(context.paddingMedium)` (~16px), so the button's bottom sits within ~16px of the raw screen height, not clearing the 48px inset.

- [ ] **Step 3: Add the missing bottom inset**

In `lib/features/farm/presentation/pages/revenue_page.dart`, inside `_AddRevenuePageState.build`, find:

```dart
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.paddingMedium),
```

Replace with:

```dart
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.paddingMedium,
            context.paddingMedium,
            context.paddingMedium,
            context.paddingMedium + context.systemBottomInset,
          ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/add_revenue_page_test.dart`
Expected: PASS

- [ ] **Step 5: Run `flutter analyze` on the changed file**

Run: `flutter analyze lib/features/farm/presentation/pages/revenue_page.dart`
Expected: no new issues beyond what already exists in the file

- [ ] **Step 6: Commit**

```bash
git add lib/features/farm/presentation/pages/revenue_page.dart test/features/farm/presentation/pages/add_revenue_page_test.dart
git commit -m "fix Save Revenue button sitting behind the system nav bar

AddRevenuePage's scroll padding was a flat constant that never
accounted for the system nav bar inset. Add context.systemBottomInset
to the bottom padding, same extension already used elsewhere."
```

---

## Plan-Level Verification

After both tasks:

- [ ] Run the full test suite: `flutter test`
  Expected: all tests pass except the pre-existing, unrelated `test/widget_test.dart` "Counter increments smoke test" failure.
- [ ] Run `flutter analyze lib/`
  Expected: same issue count as before this plan (no new warnings/errors introduced).
