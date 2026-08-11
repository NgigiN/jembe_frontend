# Frontend polish: loading states, navigation motion, safe-area fix

Date: 2026-08-01
Status: Approved

## Problem

Three related but independent frontend issues, raised together because they're all "make the app feel premium before pushing":

1. **Loading states** use a bare `CircularProgressIndicator` for whole-page/section content loads across ~15 pages. Modern apps show a skeleton of the real layout instead, so nothing jumps when data arrives and the wait feels shorter.
2. **Navigation motion** feels like screens "stack and unstack." Root cause: `AppRouter._slidePage` (`lib/core/navigation/app_router.dart`) only animates the *incoming* page's position via `SlideTransition`; it never uses `secondaryAnimation`, so the outgoing page is frozen underneath while the new one nudges in from a 25%-offset start (not even a full off-screen slide). On pop, the reverse happens: the popped page nudges back out and disappears, revealing a background that never moved. Confirmed with looping CSS mockups during design review; the frozen-background artifact was clearly visible.
3. **Safe-area bug**: the "Add Season" submit button sits behind the 3-button Android system nav bar. Every other page's bottom sheet (`activity_page.dart`, `herd_page.dart`, `input_page.dart`, `infrastructure_page.dart`, `harvest_page.dart`) goes through the shared `EntityFormSheet` helper (`lib/core/widgets/crud/entity_form_sheet.dart`), which sets `useSafeArea: true` and pads for `MediaQuery.paddingOf(context).bottom`. `season_page.dart` hand-rolled its own `showModalBottomSheet` (both Add and Edit Season) instead and dropped that handling.

   Separately, the same underlying mistake (a bottom-anchored button with no bottom-inset padding) also affects `AddRevenuePage` in `revenue_page.dart` - but it's not a modal sheet, it's a full page whose `SingleChildScrollView` pads with the fixed `context.paddingMedium` (~16px) instead of accounting for `context.systemBottomInset` (already defined in `lib/core/utils/safe_layout_utils.dart` and used elsewhere, e.g. `season_page.dart`'s `context.scrollListPadding`). `revenue_page.dart`'s other bottom sheet (`RevenueDetailsSheet`, the read-only detail view) already correctly pads for `MediaQuery.of(context).padding.bottom` - it is not part of this bug.

## Approach

### 1. Loading states: Skeletonizer

Add the `skeletonizer` package (`flutter pub add skeletonizer`). Rule for what changes:

- **Replace with a skeleton:** any spinner that is the primary content of a page or major section while its data loads - i.e. every `BlocBuilder` branch that currently returns `Center(child: CircularProgressIndicator())` as the whole page/section body. This covers the list pages (Plants, Lands, Seasons, Animal Types, Herds, Animals, Infrastructure, Inputs, Activities, Revenue, Harvests), the Analytics pages (Unified Costs, Cost Breakdown, Annual Summary, and its profile-fetch gate), and Herd Activity's page-level herd-dependency gate.
- **Leave as a spinner:** anything inside a button/icon while an action is submitting (Settings save, onboarding submit, Google sign-in, Record Activity), and small inline loaders inside a form field (the herd/season dropdown suffix-icon loaders in `activity_page.dart` and `cost_category_type_selector.dart`). These communicate "an action is in flight," not "content is loading" - a skeleton would be the wrong signal there.
- Splash screen keeps its own spinner; it's a branded loading screen, not content.

Implementation pattern: build one reusable `SkeletonEntityList` widget (new, under `lib/core/widgets/loading/`) that wraps `Skeletonizer` around a handful of placeholder `EntityCard`-shaped rows, since nearly every list page already renders through the shared `EntityCard` widget. Pages with a different shape (Analytics overview stat cards, Annual Summary's header card) get a small bespoke skeleton following the same wrap-the-real-layout-in-`Skeletonizer` approach rather than a hand-built gray-box placeholder. Exact per-page wiring is implementation-plan detail, not design detail.

### 2. Navigation motion: official Material Motion (`animations` package)

Add the `animations` package (`flutter pub add animations`) - Google's own Flutter team package, not a third-party reimplementation.

- **`_slidePage`** (used for all drill-down detail routes: Lands, Plants, Seasons, Animal Types, Herds, Inputs, Activities, Total Costs, Cost Breakdown, Annual Summary, Add Revenue, Infrastructure, Herd Activities, Harvests): replace the hand-rolled `SlideTransition` with `SharedAxisTransition(transitionType: SharedAxisTransitionType.horizontal, animation: animation, secondaryAnimation: secondaryAnimation, child: child)`. This is what fixes the frozen-background bug - both screens are driven from the same transition and move together.
- **New `_fadeThroughPage` helper**, using `FadeThroughTransition`. Convert the 5 bottom-nav tab routes inside the `ShellRoute` (Plants, Analytics, Animals, Revenue, Settings - currently plain `builder:`, no transition control) to `pageBuilder:` using it. Tabs aren't hierarchically related to each other, so a directional slide would be semantically wrong; a fade-through content-swap is the correct pattern (confirmed via mockup).
- Both transitions need a `fillColor` (use `Theme.of(context).colorScheme.surface`) so the cross-fade doesn't show through to whatever's behind during the dip.
- Respect reduced motion: check `MediaQuery.disableAnimationsOf(context)` in both helpers and fall back to an instant cut (zero-duration `FadeTransition` or similar) when true. This is an accessibility requirement, not optional.

### 3. Safe-area bug: two independent fixes

- `season_page.dart`: rewrite both `showModalBottomSheet` calls (add + edit season) to use `EntityFormSheet.container()` / `.scrollableForm()` with `useSafeArea: true`, exactly like `activity_page.dart` and `herd_page.dart` already do. No new pattern - just stop duplicating the bottom sheet by hand.
- `revenue_page.dart`'s `AddRevenuePage`: change its `SingleChildScrollView`'s padding from a flat `EdgeInsets.all(context.paddingMedium)` to add `context.systemBottomInset` on the bottom edge, so the "Save Revenue" button clears the system nav bar. This isn't a modal sheet, so it doesn't go through `EntityFormSheet` - it's a plain padding fix using the extension that already exists in `safe_layout_utils.dart`.

## Testing

- Widget tests for the new `SkeletonEntityList` component (renders placeholder count, wraps in `Skeletonizer`, `enabled` toggles correctly).
- Widget/golden-style test confirming the two fixed pages' submit buttons render above `MediaQuery.paddingOf(context).bottom` (regression test for the safe-area bug).
- No new tests planned for the transition helpers themselves beyond a smoke test that routes still build - motion curves aren't meaningfully unit-testable, and the design was already visually validated during brainstorming.

## Out of scope

- Predictive-back gesture support (Android 14+ peek-behind-on-swipe) - real trend, but a separate, bigger platform-integration effort, not part of this pass.
- `OpenContainerTransform` (card-morphs-into-detail shared-element transitions) - a further-out enhancement, not needed to fix the two problems raised here.
- Any other frontend polish not explicitly raised (this spec is scoped to loading states, navigation motion, and the safe-area bug only).
