import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getLightTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTypography.getTextTheme(),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.getTextTheme().titleLarge?.copyWith(
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: AppTypography.getTextTheme().labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
      extensions: [
        StatusColors(
          positive: AppColors.primaryGreen.shade700,
          warning: AppColors.primaryAmber.shade800,
          negative: AppColors.errorRed.shade700,
        ),
      ],
    );
  }

  static ThemeData getDarkTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTypography.getTextTheme().apply(
        bodyColor: Colors.white70,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.getTextTheme().titleLarge?.copyWith(
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: AppTypography.getTextTheme().labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
      extensions: [
        StatusColors(
          positive: AppColors.primaryGreen.shade300,
          warning: AppColors.primaryAmber.shade300,
          negative: AppColors.errorRed.shade300,
        ),
      ],
    );
  }
}
