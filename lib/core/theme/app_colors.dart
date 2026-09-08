import 'package:flutter/material.dart';

class AppColors {
  // Existing Base Colors
  static const MaterialColor primaryGreen = Colors.green;
  static const MaterialColor primaryBlue = Colors.blue;
  static const MaterialColor primaryOrange = Colors.orange;
  static const MaterialColor primaryPurple = Colors.purple;
  static const MaterialColor primaryAmber = Colors.amber;
  static const MaterialColor errorRed = Colors.red;

  static const Color backgroundWhite = Colors.white;
  static const Color textBlack = Colors.black87;
  static const Color textGrey = Colors.grey;

  // Material 3 Light Color Scheme. Seeded via ColorScheme.fromSeed so the
  // full surface family (surfaceContainerLow/Container/High/Highest,
  // outline, surfaceTint, ...) is generated as a harmonized tonal palette
  // instead of hand-picked flat greys, then the brand's explicit role
  // colors are layered on top with copyWith. Only used when the platform
  // has no Material You dynamic color to offer (see main.dart) - dynamic
  // color takes over the whole scheme, generated surfaces included, when
  // it's available.
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: primaryGreen,
  ).copyWith(
    primary: primaryGreen.shade600,
    onPrimary: Colors.white,
    primaryContainer: primaryGreen.shade100,
    onPrimaryContainer: primaryGreen.shade900,

    secondary: primaryPurple.shade600,
    onSecondary: Colors.white,
    secondaryContainer: primaryPurple.shade100,
    onSecondaryContainer: primaryPurple.shade900,

    tertiary: primaryBlue.shade600,
    onTertiary: Colors.white,
    tertiaryContainer: primaryBlue.shade100,
    onTertiaryContainer: primaryBlue.shade900,

    error: errorRed,
    onError: Colors.white,
    errorContainer: errorRed.shade100,
    onErrorContainer: errorRed.shade900,
  );

  // Material 3 Dark Color Scheme. See lightColorScheme above for why this
  // is seed-generated rather than flat literals.
  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: primaryGreen,
    brightness: Brightness.dark,
  ).copyWith(
    primary: primaryGreen.shade400,
    onPrimary: Colors.black,
    primaryContainer: primaryGreen.shade800,
    onPrimaryContainer: primaryGreen.shade100,

    secondary: primaryPurple.shade300,
    onSecondary: Colors.black,
    secondaryContainer: primaryPurple.shade800,
    onSecondaryContainer: primaryPurple.shade100,

    tertiary: primaryBlue.shade300,
    onTertiary: Colors.black,
    tertiaryContainer: primaryBlue.shade800,
    onTertiaryContainer: primaryBlue.shade100,

    error: errorRed.shade400,
    onError: Colors.black,
    errorContainer: errorRed.shade900,
    onErrorContainer: errorRed.shade200,
  );

  // Semantic Categories
  static Color get plantCategory => primaryBlue;
  static Color get animalCategory => primaryOrange;
  static Color get plantCategoryLight => primaryBlue.shade100;
  static Color get animalCategoryLight => primaryOrange.shade100;
}
