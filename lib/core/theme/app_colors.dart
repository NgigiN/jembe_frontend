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
    keyColors: const FlexKeyColors(useKeyColors: true, keepPrimary: true),
    surface: _lightSurface,
    onSurface: _lightOnSurface,
    useMaterial3: true,
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
    keyColors: const FlexKeyColors(useKeyColors: true),
    useMaterial3: true,
  ).toScheme;

  // Status tokens — fixed per theme brightness, never seed-derived (spec §3:
  // green-for-good/red-for-bad must not shift with the palette). Re-picked
  // from the old Colors.green/.amber/.red shades to read correctly against
  // the new surfaces; contrast-verified in status_colors_contrast_test.dart
  // (Task 2). Values may be adjusted during the screen-review tasks
  // (Tasks 10-15) if they read wrong on a live screen.
  static const Color statusPositiveLight = Color(0xFF2E7D32);
  static const Color statusWarningLight = Color(0xFFB26A00);
  static const Color statusNegativeLight = Color(0xFFB3261E);
  static const Color statusPositiveDark = Color(0xFF7BC67E);
  static const Color statusWarningDark = Color(0xFFFFB74D);
  static const Color statusNegativeDark = Color(0xFFF2B8B5);

  // Identity colors for plant/animal categories — harmonized with
  // brandSeed, not derived from it (spec §3, implementer judgment call,
  // called out in the PR). Muted teal-blue and warm terracotta: distinct
  // from the brand green and from each other, neither reads as a status
  // color (no green/amber/red).
  static const Color plantCategory = Color(0xFF3E6B8A);
  static const Color plantCategoryLight = Color(0xFFD4E3EC);
  static const Color animalCategory = Color(0xFFB8622A);
  static const Color animalCategoryLight = Color(0xFFF0DACB);
}
