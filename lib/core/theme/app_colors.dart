import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppColors {
  // Single source of truth for the app's color identity (design-system-
  // foundation spec §3) — everything else in this class and in app_theme.dart
  // derives from or sits alongside this one seed. Changing the palette later
  // is a one-line edit here.
  static const Color brandSeed = Color(0xFF2E7D32);

  // Exact marketing-site values (frontend/docs/styles.css) — passed
  // explicitly rather than left to seed-derivation, which would not
  // reproduce these exact bytes.
  static const Color _lightSurface = Color(0xFFF6F7F4);
  static const Color _lightOnSurface = Color(0xFF111511);

  // `keepPrimary: true` pins ColorScheme.primary to the literal brandSeed:
  // M3 tonal generation alone places primary at a derived tone close to but
  // not byte-identical to the seed (verified empirically). The brand green
  // must be the literal, exact #2E7D32 wherever it renders as primary;
  // everything *derived from* that primary (secondary, tertiary, containers,
  // tones) still comes from seed generation.
  static final ColorScheme lightColorScheme = FlexColorScheme.light(
    colors: FlexSchemeColor.from(primary: brandSeed),
    keyColors: const FlexKeyColors(keepPrimary: true),
    surface: _lightSurface,
    onSurface: _lightOnSurface,
  ).toScheme;

  // Dark mode is the same seed run through FlexColorScheme.dark, not a
  // second hand-picked palette (spec §3) — no explicit primary/surface/
  // onSurface override here, unlike the light scheme. Research only
  // specifies the exact literal brandSeed for the light ("on white") case;
  // forcing that same mid-tone green as dark mode's primary would fail M3's
  // own reasoning for using a lighter tone (M3 tone ~80) against a dark
  // surface — pinning it would trade legibility for an exactness the spec
  // never asked for in dark mode. Left to keyColors' own per-brightness
  // tonal derivation from the same seed.
  static final ColorScheme darkColorScheme = FlexColorScheme.dark(
    colors: FlexSchemeColor.from(primary: brandSeed),
    keyColors: const FlexKeyColors(),
  ).toScheme;

  // Status tokens — fixed per theme brightness, never seed-derived (spec §3:
  // green-for-good/red-for-bad must not shift with the palette). Re-picked
  // from the old Colors.green/.amber/.red shades to read correctly against
  // the new surfaces; contrast-verified in status_colors_contrast_test.dart
  // (Task 2). Values may be adjusted during the screen-review tasks
  // (Tasks 10-15) if they read wrong on a live screen.
  static const Color statusPositiveLight = Color(0xFF2E7D32);
  // #B26A00 (4.7:1) at first pass fell to 3.94:1 once the exact warm surface
  // (#F6F7F4, lighter than pure white) was substituted in — darkened until
  // it cleared WCAG AA 4.5:1 (verified in status_colors_contrast_test.dart).
  static const Color statusWarningLight = Color(0xFFA05F00);
  static const Color statusNegativeLight = Color(0xFFB3261E);
  static const Color statusPositiveDark = Color(0xFF7BC67E);
  static const Color statusWarningDark = Color(0xFFFFB74D);
  static const Color statusNegativeDark = Color(0xFFF2B8B5);

  // Identity colors for plant/animal categories — harmonized with
  // brandSeed, not derived from it (spec §3, implementer judgment call,
  // called out in the PR). Muted teal-blue and warm terracotta: distinct
  // from the brand green and from each other, neither reads as a status
  // color (no green/amber/red).
  //
  // Naming note: the `…Light` suffix means "the light *container* tint"
  // (the pale chip behind the icon), not "the light theme" — both of the
  // pairs below are the light-theme values. The dark theme's equivalents
  // are the `…Dark` / `…DarkContainer` pairs further down.
  static const Color plantCategory = Color(0xFF3E6B8A);
  static const Color plantCategoryLight = Color(0xFFD4E3EC);
  static const Color animalCategory = Color(0xFFB8622A);
  static const Color animalCategoryLight = Color(0xFFF0DACB);

  // Dark-theme category pairs (DESIGN_SPEC §1, "Color — dark" row): the
  // same two hues re-picked for a dark ground, not the light values
  // reused — the light teal/terracotta both fail contrast on #1A1F19.
  static const Color plantCategoryDark = Color(0xFF9FC4DD);
  static const Color plantCategoryDarkContainer = Color(0xFF22394B);
  static const Color animalCategoryDark = Color(0xFFE8A47A);
  static const Color animalCategoryDarkContainer = Color(0xFF4A2A16);

  // Web console tokens (docs/UI mockups brand decision/handoff/DESIGN_SPEC.md
  // §1) — explicit named constants, same reasoning as the status/category
  // tokens above: M3 seed-derivation doesn't reproduce these exact bytes,
  // and the mockups were authored against these literal values.
  //
  // `ground` is the page + sidebar floor; `surface` (the ColorScheme role)
  // is the white a card sits on top of it. M3 dropped the `background`
  // role, so the distinction the mockups rely on lives here instead.
  static const Color groundLight = Color(0xFFF6F7F4);
  static const Color surfaceLowLight = Color(0xFFEEF0EB);
  static const Color surfaceContainerLight = Color(0xFFE4E7E1);
  static const Color onSurface2Light = Color(0xFF3F473D);
  static const Color mutedLight = Color(0xFF6B7368);
  static const Color outlineLight = Color(0xFFD3D8CF);
  static const Color negativeContainerLight = Color(0xFFF9DEDC);
  // Sign-in brand panel only — not used anywhere else, and identical in
  // both themes: the panel is always a deep green field.
  static const Color deep = Color(0xFF1B5E20);

  static const Color groundDark = Color(0xFF10140F);
  static const Color surfaceLowDark = Color(0xFF20261F);
  static const Color surfaceContainerDark = Color(0xFF2A312A);
  static const Color onSurface2Dark = Color(0xFFC2C9BD);
  static const Color mutedDark = Color(0xFF8C9388);
  static const Color outlineDark = Color(0xFF3A423A);
  static const Color negativeContainerDark = Color(0xFF5B1A16);

  // M3 scheme roles the console pins rather than inherits (DESIGN_SPEC §1).
  // The mockups were drawn against these exact tones; seed derivation lands
  // near them but not on them, and the difference is visible where a tonal
  // button sits beside a filled one. Applied only to the web console's own
  // ColorScheme (see WebConsoleTheme) — the mobile app keeps the derived
  // scheme, so pinning here carries no mobile blast radius.
  static const Color primaryContainerWebLight = Color(0xFFB7EFB4);
  static const Color onPrimaryContainerWebLight = Color(0xFF002106);
  static const Color surfaceWebLight = Color(0xFFFFFFFF);
  static const Color onSurfaceWebLight = Color(0xFF111511);

  static const Color primaryWebDark = Color(0xFF9CD69A);
  static const Color onPrimaryWebDark = Color(0xFF003910);
  static const Color primaryContainerWebDark = Color(0xFF0F5216);
  static const Color onPrimaryContainerWebDark = Color(0xFFB7EFB4);
  static const Color surfaceWebDark = Color(0xFF1A1F19);
  static const Color onSurfaceWebDark = Color(0xFFE0E4DC);
}
