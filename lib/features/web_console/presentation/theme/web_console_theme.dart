import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/app_theme.dart';
import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// The web console's ThemeData (DESIGN_SPEC §1).
///
/// Deliberately separate from [AppTheme]: the console pins several M3
/// scheme roles to the exact tones the mockups were drawn against, and
/// wants web-shaped control defaults (36px buttons, 10px radii, flat
/// outlined cards) that would be wrong on a phone. Keeping it here means
/// the mobile app's theme is untouched by any of it.
///
/// The brand identity is still shared — both themes derive from
/// [AppColors.brandSeed] and use [AppTypography]'s families.
abstract final class WebConsoleTheme {
  static ThemeData light() =>
      _build(_lightScheme(), const ConsoleColors.light(), Brightness.light);

  static ThemeData dark() =>
      _build(_darkScheme(), const ConsoleColors.dark(), Brightness.dark);

  static ColorScheme _lightScheme() {
    return AppColors.lightColorScheme.copyWith(
      // `surface` is the white a card is drawn in; the page floor is
      // ConsoleColors.ground, applied as scaffoldBackgroundColor below.
      surface: AppColors.surfaceWebLight,
      onSurface: AppColors.onSurfaceWebLight,
      primaryContainer: AppColors.primaryContainerWebLight,
      onPrimaryContainer: AppColors.onPrimaryContainerWebLight,
      outline: AppColors.outlineLight,
      error: AppColors.statusNegativeLight,
      errorContainer: AppColors.negativeContainerLight,
    );
  }

  static ColorScheme _darkScheme() {
    return AppColors.darkColorScheme.copyWith(
      primary: AppColors.primaryWebDark,
      onPrimary: AppColors.onPrimaryWebDark,
      primaryContainer: AppColors.primaryContainerWebDark,
      onPrimaryContainer: AppColors.onPrimaryContainerWebDark,
      surface: AppColors.surfaceWebDark,
      onSurface: AppColors.onSurfaceWebDark,
      outline: AppColors.outlineDark,
      error: AppColors.statusNegativeDark,
      errorContainer: AppColors.negativeContainerDark,
    );
  }

  static ThemeData _build(
    ColorScheme scheme,
    ConsoleColors console,
    Brightness brightness,
  ) {
    final textTheme = AppTypography.getTextTheme().apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: console.ground,
      canvasColor: console.ground,
      dividerTheme: DividerThemeData(
        color: console.outline,
        thickness: 1,
        space: 1,
      ),
      // Console cards are flat: a 1px outline plus the single hairline
      // shadow from ConsoleMetrics, drawn by ConsoleCard itself. Material's
      // own elevation is turned off so the two don't stack.
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ConsoleMetrics.radiusCard),
          side: BorderSide(color: console.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle().copyWith(
          side: WidgetStatePropertyAll(BorderSide(color: console.outline)),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: _buttonStyle()),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: console.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: console.onSurface2, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: AppTypography.bodyDense.copyWith(color: console.muted),
        border: _inputBorder(console.outline),
        enabledBorder: _inputBorder(console.outline),
        focusedBorder: _inputBorder(scheme.primary),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error),
      ),
      extensions: [
        console,
        StatusColors(
          positive: brightness == Brightness.dark
              ? AppColors.statusPositiveDark
              : AppColors.statusPositiveLight,
          warning: brightness == Brightness.dark
              ? AppColors.statusWarningDark
              : AppColors.statusWarningLight,
          negative: brightness == Brightness.dark
              ? AppColors.statusNegativeDark
              : AppColors.statusNegativeLight,
        ),
      ],
    );
  }

  static ButtonStyle _buttonStyle() {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(0, ConsoleMetrics.buttonHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      textStyle: const WidgetStatePropertyAll(AppTypography.navItem),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
        ),
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
      borderSide: BorderSide(color: color),
    );
  }
}
