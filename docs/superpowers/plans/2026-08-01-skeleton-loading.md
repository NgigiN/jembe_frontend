# Skeleton Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bare `CircularProgressIndicator` shown while list pages load their content with a `Skeletonizer`-based skeleton that matches the real layout.

**Architecture:** One reusable `SkeletonEntityList` widget (fixed `enabled: true`, since it's only ever rendered from the `Loading` branch of a page's `BlocBuilder` - once data loads, the page switches to a different branch entirely, so there's no need to dynamically toggle skeleton mode on the same widget tree). Apply it to every page whose Loading branch is exactly `if (state is XLoading && state.items.isEmpty) { return const Center(child: CircularProgressIndicator()); }` followed by a `ListView.builder` of `EntityCard`s - confirmed identical in 8 files.

**Tech Stack:** Flutter, `skeletonizer` package, `flutter_test`.

## Global Constraints

- Add exactly one new dependency: `skeletonizer` (via `flutter pub add skeletonizer`, no pinned version - let pub resolve latest compatible with `sdk: ^3.8.0`).
- Only touch the `Loading` branch of each page's `BlocBuilder`. Don't touch the Error/Empty/Loaded branches, the FAB, or anything else on the page.
- Every page covered here must keep passing `flutter analyze` with no new issues.

## Out of Scope (do not implement in this plan)

The following pages have a `CircularProgressIndicator` that is NOT a simple `EntityCard` list, so they need a bespoke skeleton shape, not `SkeletonEntityList`. Confirmed by reading each file - deliberately deferred to a follow-up plan rather than rushed here:

- `plants_page.dart` / `animals_page.dart` - "setup steps" dashboards (`SetupStepCard`/`StepConnector`), not entity lists.
- `herd_activity_page.dart` - custom activity-card shape, not `EntityCard`.
- `analysis_page.dart` (4 spots: Unified Costs, Cost Breakdown, Annual Summary body, Annual Summary's profile-fetch gate) - Analytics-specific stat cards and breakdown rows.
- Button/action-in-progress spinners anywhere (Settings save, onboarding submit, Google sign-in, Record Activity, the two inline dropdown loaders) - these are correctly spinners already, per the design spec.

---

### Task 1: Build the reusable `SkeletonEntityList` widget

**Files:**
- Modify: `pubspec.yaml` (add `skeletonizer` dependency)
- Create: `lib/core/widgets/loading/skeleton_entity_list.dart`
- Test: `test/core/widgets/loading/skeleton_entity_list_test.dart` (new)

**Interfaces:**
- Produces: `SkeletonEntityList({Key? key, IconData icon = Icons.circle, int itemCount = 6})`, a `StatelessWidget`. Every later task in this plan drops this in wherever a page's Loading branch currently returns `Center(child: CircularProgressIndicator())`.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add skeletonizer`
Expected: `pubspec.yaml` gains a `skeletonizer: ^<resolved version>` line under `dependencies`, and `flutter pub get` runs automatically as part of `pub add`.

- [ ] **Step 2: Write the failing test**

Create `test/core/widgets/loading/skeleton_entity_list_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';

void main() {
  testWidgets(
    'renders itemCount placeholder cards wrapped in an enabled Skeletonizer',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonEntityList(itemCount: 3, icon: Icons.eco),
          ),
        ),
      );

      expect(find.byType(Skeletonizer), findsOneWidget);
      expect(find.byType(EntityCard), findsNWidgets(3));

      final skeletonizer =
          tester.widget<Skeletonizer>(find.byType(Skeletonizer));
      expect(skeletonizer.enabled, isTrue);
    },
  );

  testWidgets('defaults to 6 placeholder cards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SkeletonEntityList()),
      ),
    );

    expect(find.byType(EntityCard), findsNWidgets(6));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/widgets/loading/skeleton_entity_list_test.dart`
Expected: FAIL - `lib/core/widgets/loading/skeleton_entity_list.dart` does not exist yet (import error).

- [ ] **Step 4: Implement `SkeletonEntityList`**

Create `lib/core/widgets/loading/skeleton_entity_list.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';

/// A loading placeholder for pages that show a list of [EntityCard]s.
///
/// Always skeletonized - only render this from a `BlocBuilder`'s Loading
/// branch. Once data loads, the page should switch to its normal branch
/// with real [EntityCard]s, not toggle this widget's skeleton state.
class SkeletonEntityList extends StatelessWidget {
  const SkeletonEntityList({
    super.key,
    this.icon = Icons.circle,
    this.itemCount = 6,
  });

  final IconData icon;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) => EntityCard(
          icon: icon,
          iconColor: Colors.grey,
          title: 'Loading title placeholder',
          subtitle: 'Loading subtitle placeholder text',
          onTap: () {},
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/widgets/loading/skeleton_entity_list_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/widgets/loading/skeleton_entity_list.dart test/core/widgets/loading/skeleton_entity_list_test.dart
git commit -m "add reusable SkeletonEntityList loading placeholder

Wraps a fixed number of placeholder EntityCards in Skeletonizer.
First user of the skeletonizer package added in this commit."
```

---

### Task 2: Apply `SkeletonEntityList` to the 8 confirmed simple list pages

**Files:**
- Modify: `lib/features/farm/presentation/pages/land_page.dart:66`
- Modify: `lib/features/farm/presentation/pages/animal_type_page.dart:62`
- Modify: `lib/features/farm/presentation/pages/infrastructure_page.dart:72`
- Modify: `lib/features/farm/presentation/pages/harvest_page.dart:74`
- Modify: `lib/features/farm/presentation/pages/input_page.dart:95`
- Modify: `lib/features/farm/presentation/pages/activity_page.dart:96`
- Modify: `lib/features/farm/presentation/pages/herd_page.dart:68`
- Modify: `lib/features/farm/presentation/pages/season_page.dart:78`
- Test: `test/features/farm/presentation/pages/land_page_test.dart` (new - representative test; the other 7 pages use the byte-for-byte identical pattern verified by Task 1's test plus this one, so they are not each given a bespoke test - see Step 6)

**Interfaces:**
- Consumes: `SkeletonEntityList` from Task 1.

- [ ] **Step 1: Write the failing representative test (land_page.dart)**

First, check `land_page.dart`'s FAB icon and page structure so the test targets the right widget - it uses the same `LandLoading`/`LandLoaded`/`LandError` states as elsewhere in this codebase.

Create `test/features/farm/presentation/pages/land_page_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/land_page.dart';

class MockLandBloc extends MockBloc<LandEvent, LandState>
    implements LandBloc {}

void main() {
  testWidgets(
    'shows a skeleton (not a spinner) while lands are loading',
    (tester) async {
      final landBloc = MockLandBloc();
      whenListen(
        landBloc,
        Stream<LandState>.value(const LandLoading()),
        initialState: const LandLoading(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<LandBloc>.value(
            value: landBloc,
            child: const LandPage(),
          ),
        ),
      );

      expect(find.byType(Skeletonizer), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/land_page_test.dart`
Expected: FAIL - `find.byType(Skeletonizer)` finds nothing; the page still shows a `CircularProgressIndicator`.

- [ ] **Step 3: Wire `SkeletonEntityList` into `land_page.dart`**

Add the import:

```dart
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
```

Replace:

```dart
          if (state is LandLoading && state.lands.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
```

with:

```dart
          if (state is LandLoading && state.lands.isEmpty) {
            return const SkeletonEntityList(icon: Icons.landscape);
          }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/land_page_test.dart`
Expected: PASS

- [ ] **Step 5: Apply the identical fix to the remaining 7 pages**

Each of these has the exact same shape (`if (state is XLoading && state.items.isEmpty) { return const Center(child: CircularProgressIndicator()); }`) - add the `SkeletonEntityList` import and replace that one line in each:

`lib/features/farm/presentation/pages/animal_type_page.dart`:
```dart
          if (state is AnimalTypeLoading && state.animalTypes.isEmpty) {
            return const SkeletonEntityList(icon: Icons.pets);
          }
```

`lib/features/farm/presentation/pages/infrastructure_page.dart`:
```dart
          if (state is InfrastructureLoading && state.infrastructures.isEmpty) {
            return const SkeletonEntityList(icon: Icons.home_work);
          }
```

`lib/features/farm/presentation/pages/harvest_page.dart`:
```dart
          if (state is HarvestLoading && state.harvests.isEmpty) {
            return const SkeletonEntityList(icon: Icons.agriculture);
          }
```

`lib/features/farm/presentation/pages/input_page.dart`:
```dart
          if (state is InputLoading && state.inputs.isEmpty) {
            return const SkeletonEntityList(icon: Icons.inventory_2);
          }
```

`lib/features/farm/presentation/pages/activity_page.dart` (the page-level spot at the top of the file's `BlocBuilder`, not the two inline dropdown spinners further down - those stay as-is):
```dart
          if (state is ActivityLoading && state.activities.isEmpty) {
            return const SkeletonEntityList(icon: Icons.checklist);
          }
```

`lib/features/farm/presentation/pages/herd_page.dart`:
```dart
          if (state is HerdLoading && state.herds.isEmpty) {
            return const SkeletonEntityList(icon: Icons.pets);
          }
```

`lib/features/farm/presentation/pages/season_page.dart`:
```dart
          if (state is SeasonLoading && state.seasons.isEmpty) {
            return const SkeletonEntityList(icon: Icons.calendar_today);
          }
```

Add `import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';` to each of these 7 files as well.

- [ ] **Step 6: Verify the batch change**

Run: `flutter analyze lib/features/farm/presentation/pages/`
Expected: no new issues beyond what already existed before this task.

Run: `flutter test`
Expected: all tests pass except the pre-existing, unrelated `test/widget_test.dart` "Counter increments smoke test" failure. This confirms none of the 7 mechanically-identical edits broke anything - they're covered by the existing test suite's coverage of each page's Loaded/Error/Empty branches, which are untouched, plus `land_page_test.dart`'s proof that the underlying pattern works.

- [ ] **Step 7: Commit**

```bash
git add lib/features/farm/presentation/pages/land_page.dart lib/features/farm/presentation/pages/animal_type_page.dart lib/features/farm/presentation/pages/infrastructure_page.dart lib/features/farm/presentation/pages/harvest_page.dart lib/features/farm/presentation/pages/input_page.dart lib/features/farm/presentation/pages/activity_page.dart lib/features/farm/presentation/pages/herd_page.dart lib/features/farm/presentation/pages/season_page.dart test/features/farm/presentation/pages/land_page_test.dart
git commit -m "replace loading spinners with SkeletonEntityList on the 8 simple list pages

Lands, Animal Types, Infrastructure, Harvests, Inputs, Activities,
Herds, Seasons all shared the identical
'Center(child: CircularProgressIndicator())' Loading branch feeding a
ListView.builder of EntityCards - swapped all 8 for the skeleton
placeholder built in the previous commit."
```

---

## Plan-Level Verification

- [ ] Run `flutter test` - all pass except the pre-existing `widget_test.dart` failure.
- [ ] Run `flutter analyze lib/` - no new issues.
- [ ] Manually launch the app (`flutter run`), throttle network if possible, and visually confirm at least one page (e.g. Lands) shows the shimmering skeleton instead of a spinner while loading.
