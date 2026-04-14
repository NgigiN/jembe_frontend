import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.lightColorScheme,
      textTheme: AppTypography.getTextTheme(),
      scaffoldBackgroundColor: AppColors.backgroundWhite,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightColorScheme.primary,
        foregroundColor: AppColors.lightColorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.getTextTheme().titleLarge?.copyWith(
          color: AppColors.lightColorScheme.onPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightColorScheme.primary,
          foregroundColor: AppColors.lightColorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 24,
          ),
          textStyle: AppTypography.getTextTheme().labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.darkColorScheme,
      textTheme: AppTypography.getTextTheme().apply(
        bodyColor: Colors.white70,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.darkColorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkColorScheme.primaryContainer,
        foregroundColor: AppColors.darkColorScheme.onPrimaryContainer,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.getTextTheme().titleLarge?.copyWith(
          color: AppColors.darkColorScheme.onPrimaryContainer,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkColorScheme.primary,
          foregroundColor: AppColors.darkColorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 24,
          ),
          textStyle: AppTypography.getTextTheme().labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkColorScheme.surfaceContainerHighest,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: AppColors.darkColorScheme.surfaceContainerHighest,
      ),
    );
  }
}
