import 'package:flutter/material.dart';

/// The console's shape, spacing and elevation constants (DESIGN_SPEC §1
/// "Shape & elevation" and "Spacing").
///
/// These are named so a page never writes a bare `14` and leaves the next
/// reader guessing whether it meant a card radius or a coincidence. Every
/// value below is lifted straight from the spec.
abstract final class ConsoleMetrics {
  // Radii.
  static const double radiusCard = 14;
  static const double radiusControl = 10; // buttons, inputs, nav items
  static const double radiusSmallButton = 8;
  static const double radiusTile = 12;
  static const double radiusTag = 6;

  // Spacing.
  static const EdgeInsets mainPadding = EdgeInsets.symmetric(
    vertical: 22,
    horizontal: 28,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const double gridGap = 16;
  static const EdgeInsets tableCellPadding = EdgeInsets.symmetric(
    vertical: 9,
    horizontal: 10,
  );
  static const EdgeInsets tableHeaderPadding = EdgeInsets.symmetric(
    vertical: 8,
    horizontal: 10,
  );

  // Fixed sizes.
  static const double sidebarWidth = 232;
  static const double navItemHeight = 38;
  static const double buttonHeight = 36;
  static const double inlineButtonHeight = 31;

  /// The right rail's width. The spec gives a 300–340px range; 320 is its
  /// midpoint and what the reference screens measure.
  static const double railWidth = 320;

  /// Below this the rail stacks under the main column instead of beside it
  /// (DESIGN_SPEC §2, "Responsive").
  ///
  /// Measured on the main column's own width, not the window's: at the
  /// mockups' 1280px the sidebar and page padding leave 1048px here, and
  /// the reference screens show the rail beside the content at that size.
  static const double railStackBreakpoint = 900;

  /// Below this the custom console shell hands off to the app's existing
  /// `adaptive_scaffold_plus` behaviour (rail, then bottom nav).
  static const double shellBreakpoint = 900;

  /// The console's only shadow: a 1px border does most of the lifting, and
  /// this sits under it (DESIGN_SPEC §1 — "No heavier shadows").
  static List<BoxShadow> cardShadow(Brightness brightness) {
    return [
      BoxShadow(
        color: brightness == Brightness.dark
            ? const Color(0x66000000)
            : const Color(0x0F111511),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }
}
