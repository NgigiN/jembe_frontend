import 'package:flutter/material.dart';

class AppColors {
  // Existing Base Colors
  static const MaterialColor primaryGreen = Colors.green;
  static const MaterialColor primaryBlue = Colors.blue;
  static const MaterialColor primaryOrange = Colors.orange;
  static const MaterialColor primaryPurple = Colors.purple;
  static const MaterialColor errorRed = Colors.red;

  static const Color backgroundWhite = Colors.white;
  static const Color textBlack = Colors.black87;
  static const Color textGrey = Colors.grey;

  // Material 3 Light Color Scheme
  static final ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    
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

    surface: Colors.white,
    onSurface: textBlack,
    surfaceContainerHighest: Colors.grey.shade100,
    onSurfaceVariant: Colors.grey.shade700,
    
    outline: Colors.grey.shade400,
    outlineVariant: Colors.grey.shade200,
  );

  // Material 3 Dark Color Scheme
  static final ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    
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

    surface: const Color(0xFF1E1E1E),
    onSurface: Colors.white70,
    surfaceContainerHighest: const Color(0xFF2C2C2C),
    onSurfaceVariant: Colors.white54,
    
    outline: Colors.grey.shade600,
    outlineVariant: Colors.grey.shade800,
  );

  // Semantic Categories
  static Color get plantCategory => primaryBlue;
  static Color get animalCategory => primaryOrange;
  static Color get plantCategoryLight => primaryBlue.shade100;
  static Color get animalCategoryLight => primaryOrange.shade100;
}
