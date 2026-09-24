import 'package:flutter/material.dart';

class AppTypography {
  static const _display = 'Fraunces';
  static const _body = 'WorkSans';

  static TextTheme getTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: _display,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -1,
      ),
      displayMedium: TextStyle(
        fontFamily: _display,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(fontFamily: _display, fontSize: 24, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontFamily: _display, fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontFamily: _display, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontFamily: _body, fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontFamily: _body, fontSize: 16, fontWeight: FontWeight.normal),
      bodyMedium: TextStyle(fontFamily: _body, fontSize: 14, fontWeight: FontWeight.normal),
      bodySmall: TextStyle(fontFamily: _body, fontSize: 12, fontWeight: FontWeight.normal),
      labelLarge: TextStyle(fontFamily: _body, fontSize: 14, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontFamily: _body, fontSize: 10, fontWeight: FontWeight.w500),
    );
  }

  /// Tabular figures so KES amounts align in columns (stat cards, list
  /// totals). Targeted, not a TextTheme-wide change — see design-system-
  /// foundation spec §4.
  static TextStyle money(TextStyle style) {
    return style.copyWith(
      fontFeatures: [...?style.fontFeatures, const FontFeature.tabularFigures()],
    );
  }

  // ---------------------------------------------------------------------
  // Web console ramp (DESIGN_SPEC §1 "Typography").
  //
  // These are named roles the console's own widgets ask for by name, not a
  // second TextTheme: the console needs sizes M3's eleven slots don't have
  // (17px card titles, 13px table cells, 11px kickers) and asking for
  // `titleLarge` when you mean "card title" is how a ramp drifts.
  //
  // Letter-spacing is in logical pixels, so every em figure from the spec
  // is multiplied out here: Fraunces titles carry −0.02em, kickers +0.07em.
  // ---------------------------------------------------------------------

  /// Fraunces 24/600 — the dense page title used by every console header.
  static const TextStyle pageTitle = TextStyle(
    fontFamily: _display,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.48,
    height: 1.15,
  );

  /// Fraunces 28/600 — the roomier page title (sign-in's "Sign in", the
  /// error state's headline).
  static const TextStyle pageTitleLarge = TextStyle(
    fontFamily: _display,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.56,
    height: 1.15,
  );

  /// Fraunces 17/600 — "Season log", "Invite by email", every card heading.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: _display,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.34,
  );

  /// Fraunces 19/600 — the "Shamba+" wordmark in the sidebar.
  static const TextStyle wordmark = TextStyle(
    fontFamily: _display,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.38,
  );

  /// Fraunces 46/500 — sign-in hero only. The italic half of the line is
  /// this style with `fontStyle: FontStyle.italic`.
  static const TextStyle signInHeadline = TextStyle(
    fontFamily: _display,
    fontSize: 46,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.92,
    height: 1.12,
  );

  /// Fraunces 600 with tabular figures, at one of the spec's five money /
  /// count sizes. Every KES amount and every count tile goes through here,
  /// which is what keeps digits aligned down a column.
  ///
  /// Sizes in use: 34 (largest totals), 26 (count tiles, error headline),
  /// 22 (profit row), 18, 15 (table amount cells).
  static TextStyle amount(double size) {
    return TextStyle(
      fontFamily: _display,
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: size * -0.02,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Work Sans 14/400 — default console body copy.
  static const TextStyle body = TextStyle(fontFamily: _body, fontSize: 14);

  /// Work Sans 13/400 — subtitles, helper lines, the denser body size.
  static const TextStyle bodyDense = TextStyle(fontFamily: _body, fontSize: 13);

  /// Work Sans 14/500 — a sidebar nav item. The active item is this at
  /// `FontWeight.w600`.
  static const TextStyle navItem = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Work Sans 13/400 — a table cell.
  static const TextStyle cell = TextStyle(fontFamily: _body, fontSize: 13);

  /// Work Sans 13/500 — the emphasised label inside an entry cell.
  static const TextStyle cellStrong = TextStyle(
    fontFamily: _body,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Work Sans 12/400 — labels and meta text.
  static const TextStyle meta = TextStyle(fontFamily: _body, fontSize: 12);

  /// Work Sans 11/600 uppercase, +0.07em — section kickers ("FARM",
  /// "COST BREAKDOWN") and table header cells. Callers supply the
  /// uppercasing; this is only the style.
  static const TextStyle kicker = TextStyle(
    fontFamily: _body,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.77,
  );

  /// Work Sans 11/600 — role tags ("Owner", "Manager", "Worker").
  static const TextStyle tag = TextStyle(
    fontFamily: _body,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
}
