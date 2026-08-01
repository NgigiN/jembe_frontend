# Navigation Transitions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the "stack and unstack" navigation glitch by replacing the hand-rolled, single-sided `SlideTransition` in `app_router.dart` with the official Material Motion patterns (`SharedAxisTransition` for drill-down routes, `FadeThroughTransition` for bottom-nav tab switches), both respecting reduced-motion accessibility settings.

**Architecture:** The transition-selection logic (pick `SharedAxisTransition`/`FadeThroughTransition` vs. an instant cut for reduced motion) is extracted into small public static helper methods on `AppRouter` that take `(context, animation, secondaryAnimation, child)` directly - decoupled from `GoRouterState`, so they're unit-testable without constructing a full `GoRouterState`. The existing private `_slidePage`/new `_fadeThroughPage` methods (which do need `GoRouterState`, for `state.pageKey`) just delegate to these helpers.

**Tech Stack:** Flutter, go_router, the official `animations` package (Material Motion), `flutter_test`.

## Global Constraints

- Add exactly one new dependency: `animations` (via `flutter pub add animations`, no pinned version).
- Both transitions must use `fillColor: Theme.of(context).colorScheme.surface` so the cross-fade dip doesn't show through to whatever's behind.
- Both transitions must check `MediaQuery.disableAnimationsOf(context)` and return `child` directly (no transition) when true - this is an accessibility requirement, not optional.
- `_fadePage` (splash/login/onboarding) is unchanged - not part of the reported bug, out of scope for this plan.

---

### Task 1: Replace `_slidePage`'s hand-rolled slide with `SharedAxisTransition`

**Files:**
- Modify: `pubspec.yaml` (add `animations` dependency)
- Modify: `lib/core/navigation/app_router.dart:217-237` (the `_slidePage` method)
- Test: `test/core/navigation/app_router_transitions_test.dart` (new)

**Interfaces:**
- Produces: `AppRouter.sharedAxisTransition({required BuildContext context, required Animation<double> animation, required Animation<double> secondaryAnimation, required Widget child})`, a public static method. Task 2's `fadeThroughTransitionBuilder` follows the identical shape.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add animations`
Expected: `pubspec.yaml` gains an `animations: ^<resolved version>` line under `dependencies`.

- [ ] **Step 2: Write the failing test**

Create `test/core/navigation/app_router_transitions_test.dart`:

```dart
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';

void main() {
  group('AppRouter.sharedAxisTransition', () {
    testWidgets('wraps child in a horizontal SharedAxisTransition by default',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => AppRouter.sharedAxisTransition(
              context: context,
              animation: kAlwaysCompleteAnimation,
              secondaryAnimation: kAlwaysDismissedAnimation,
              child: const Text('page content'),
            ),
          ),
        ),
      );

      expect(find.byType(SharedAxisTransition), findsOneWidget);
      final transition =
          tester.widget<SharedAxisTransition>(find.byType(SharedAxisTransition));
      expect(transition.transitionType, SharedAxisTransitionType.horizontal);
      expect(find.text('page content'), findsOneWidget);
    });

    testWidgets('skips the transition entirely when reduced motion is on',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => AppRouter.sharedAxisTransition(
                context: context,
                animation: kAlwaysCompleteAnimation,
                secondaryAnimation: kAlwaysDismissedAnimation,
                child: const Text('page content'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SharedAxisTransition), findsNothing);
      expect(find.text('page content'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/navigation/app_router_transitions_test.dart`
Expected: FAIL - `AppRouter.sharedAxisTransition` does not exist yet.

- [ ] **Step 4: Add the import and the new helper, refactor `_slidePage` to use it**

In `lib/core/navigation/app_router.dart`, add the import:

```dart
import 'package:animations/animations.dart';
```

Replace the existing `_slidePage` method:

```dart
  static CustomTransitionPage<void> _slidePage(
    Widget child,
    GoRouterState state,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0.25, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }
```

with:

```dart
  static CustomTransitionPage<void> _slidePage(
    Widget child,
    GoRouterState state,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          sharedAxisTransition(
        context: context,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      ),
    );
  }

  /// Drives both the outgoing and incoming page from the same animation,
  /// unlike a plain SlideTransition which only moves the incoming page and
  /// leaves the outgoing one frozen. Falls back to an instant cut when the
  /// user has reduced motion enabled.
  static Widget sharedAxisTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: SharedAxisTransitionType.horizontal,
      fillColor: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/navigation/app_router_transitions_test.dart`
Expected: PASS

- [ ] **Step 6: Run `flutter analyze` on the changed file**

Run: `flutter analyze lib/core/navigation/app_router.dart`
Expected: no new issues.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/navigation/app_router.dart test/core/navigation/app_router_transitions_test.dart
git commit -m "fix frozen-background transition glitch with SharedAxisTransition

_slidePage's hand-rolled SlideTransition only animated the incoming
page's position, leaving the outgoing page frozen underneath - that's
the 'stack and unstack' glitch. SharedAxisTransition (from the
official animations package) drives both pages from the same
animation instead. Also respects reduced-motion settings."
```

---

### Task 2: Add `FadeThroughTransition` for the 5 bottom-nav tab routes

**Files:**
- Modify: `lib/core/navigation/app_router.dart` (add `_fadeThroughPage` + `fadeThroughTransitionBuilder`, convert the 5 `ShellRoute` child routes from `builder:` to `pageBuilder:`)
- Test: `test/core/navigation/app_router_transitions_test.dart` (extend)

**Interfaces:**
- Consumes: same shape as Task 1's `sharedAxisTransition`.
- Produces: `AppRouter.fadeThroughTransitionBuilder({required BuildContext context, required Animation<double> animation, required Animation<double> secondaryAnimation, required Widget child})`.

- [ ] **Step 1: Write the failing test**

Add to `test/core/navigation/app_router_transitions_test.dart` (inside `main()`, alongside the existing group):

```dart
  group('AppRouter.fadeThroughTransitionBuilder', () {
    testWidgets('wraps child in a FadeThroughTransition by default',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => AppRouter.fadeThroughTransitionBuilder(
              context: context,
              animation: kAlwaysCompleteAnimation,
              secondaryAnimation: kAlwaysDismissedAnimation,
              child: const Text('tab content'),
            ),
          ),
        ),
      );

      expect(find.byType(FadeThroughTransition), findsOneWidget);
      expect(find.text('tab content'), findsOneWidget);
    });

    testWidgets('skips the transition entirely when reduced motion is on',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => AppRouter.fadeThroughTransitionBuilder(
                context: context,
                animation: kAlwaysCompleteAnimation,
                secondaryAnimation: kAlwaysDismissedAnimation,
                child: const Text('tab content'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FadeThroughTransition), findsNothing);
      expect(find.text('tab content'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/navigation/app_router_transitions_test.dart`
Expected: FAIL - `AppRouter.fadeThroughTransitionBuilder` does not exist yet.

- [ ] **Step 3: Add `fadeThroughTransitionBuilder` and `_fadeThroughPage`**

In `lib/core/navigation/app_router.dart`, add next to `sharedAxisTransition`:

```dart
  static CustomTransitionPage<void> _fadeThroughPage(
    Widget child,
    GoRouterState state,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          fadeThroughTransitionBuilder(
        context: context,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      ),
    );
  }

  /// Used for the bottom-nav tabs, which aren't hierarchically related to
  /// each other - a directional slide would be the wrong signal. Falls back
  /// to an instant cut when the user has reduced motion enabled.
  static Widget fadeThroughTransitionBuilder({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return FadeThroughTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      fillColor: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/navigation/app_router_transitions_test.dart`
Expected: PASS

- [ ] **Step 5: Wire the 5 bottom-nav tab routes to use it**

Replace the `ShellRoute`'s child routes:

```dart
      ShellRoute(
        builder: (context, state, child) => LandingPage(child: child),
        routes: [
          GoRoute(
            name: AppRouteName.plantsDashboard,
            path: '/',
            builder: (context, state) => const PlantsPage(),
          ),
          GoRoute(
            name: AppRouteName.animalsDashboard,
            path: '/animals',
            builder: (context, state) => const AnimalsPage(),
          ),
          GoRoute(
            name: AppRouteName.revenue,
            path: '/revenue',
            builder: (context, state) => const RevenuePage(),
          ),
          GoRoute(
            name: AppRouteName.analytics,
            path: '/analytics',
            builder: (context, state) => const AnalysisPage(),
          ),
          GoRoute(
            name: AppRouteName.settings,
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
```

with:

```dart
      ShellRoute(
        builder: (context, state, child) => LandingPage(child: child),
        routes: [
          GoRoute(
            name: AppRouteName.plantsDashboard,
            path: '/',
            pageBuilder: (context, state) =>
                _fadeThroughPage(const PlantsPage(), state),
          ),
          GoRoute(
            name: AppRouteName.animalsDashboard,
            path: '/animals',
            pageBuilder: (context, state) =>
                _fadeThroughPage(const AnimalsPage(), state),
          ),
          GoRoute(
            name: AppRouteName.revenue,
            path: '/revenue',
            pageBuilder: (context, state) =>
                _fadeThroughPage(const RevenuePage(), state),
          ),
          GoRoute(
            name: AppRouteName.analytics,
            path: '/analytics',
            pageBuilder: (context, state) =>
                _fadeThroughPage(const AnalysisPage(), state),
          ),
          GoRoute(
            name: AppRouteName.settings,
            path: '/settings',
            pageBuilder: (context, state) =>
                _fadeThroughPage(const SettingsPage(), state),
          ),
        ],
      ),
```

- [ ] **Step 6: Run the full test suite and analyze**

Run: `flutter test`
Expected: all pass except the pre-existing, unrelated `test/widget_test.dart` "Counter increments smoke test" failure.

Run: `flutter analyze lib/core/navigation/app_router.dart`
Expected: no new issues.

- [ ] **Step 7: Commit**

```bash
git add lib/core/navigation/app_router.dart test/core/navigation/app_router_transitions_test.dart
git commit -m "use FadeThroughTransition for bottom-nav tab switches

The 5 ShellRoute tab routes had no transition control at all
(plain builder:, not pageBuilder:). Tabs aren't hierarchically
related, so a content-swap fade-through is the correct pattern,
not a directional slide."
```

---

## Plan-Level Verification

- [ ] Run `flutter test` - all pass except the pre-existing `widget_test.dart` failure.
- [ ] Run `flutter analyze lib/` - no new issues.
- [ ] Manually launch the app (`flutter run`) and navigate: Plants -> a season -> back, and between two bottom-nav tabs. Confirm the old screen now visibly moves with the new one (no frozen background), and tab switches cross-fade instead of sliding.
