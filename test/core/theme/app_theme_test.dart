import 'package:farm_tracker/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Deliberately distinct from AppColors' real values, so a test passing
  // only because AppTheme still secretly reads AppColors internally would
  // fail these assertions instead of accidentally matching.
  const testLightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF112233),
    onPrimary: Color(0xFF000001),
    secondary: Color(0xFF223344),
    onSecondary: Color(0xFF000002),
    error: Color(0xFF334455),
    onError: Color(0xFF000003),
    surface: Color(0xFF445566),
    onSurface: Color(0xFF000004),
    surfaceContainerHighest: Color(0xFF556677),
  );

  const testDarkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF667788),
    onPrimary: Color(0xFF000005),
    secondary: Color(0xFF778899),
    onSecondary: Color(0xFF000006),
    error: Color(0xFF8899AA),
    onError: Color(0xFF000007),
    surface: Color(0xFF99AABB),
    onSurface: Color(0xFF000008),
    surfaceContainerHighest: Color(0xFFAABBCC),
  );

  group('getLightTheme', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.getLightTheme(testLightScheme);
    });

    test('uses the passed-in colorScheme as-is', () {
      expect(theme.colorScheme, testLightScheme);
    });

    test('input fields fill with a colorScheme token, not a hardcoded gray', () {
      expect(theme.inputDecorationTheme.fillColor, testLightScheme.surfaceContainerHighest);
    });

    test('scaffold background derives from colorScheme.surface, not a hardcoded white', () {
      expect(theme.scaffoldBackgroundColor, testLightScheme.surface);
    });

    test('app bar colors derive from the passed-in colorScheme', () {
      expect(theme.appBarTheme.backgroundColor, testLightScheme.primary);
      expect(theme.appBarTheme.foregroundColor, testLightScheme.onPrimary);
    });

    test('elevated button colors derive from the passed-in colorScheme', () {
      final style = theme.elevatedButtonTheme.style!;
      expect(style.backgroundColor?.resolve({}), testLightScheme.primary);
      expect(style.foregroundColor?.resolve({}), testLightScheme.onPrimary);
    });
  });

  group('getDarkTheme', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.getDarkTheme(testDarkScheme);
    });

    test('uses the passed-in colorScheme as-is', () {
      expect(theme.colorScheme, testDarkScheme);
    });

    test('input fields fill with a colorScheme token', () {
      expect(theme.inputDecorationTheme.fillColor, testDarkScheme.surfaceContainerHighest);
    });

    test('scaffold background derives from colorScheme.surface', () {
      expect(theme.scaffoldBackgroundColor, testDarkScheme.surface);
    });

    test('card color derives from the passed-in colorScheme', () {
      expect(theme.cardTheme.color, testDarkScheme.surfaceContainerHighest);
    });

    test('app bar colors derive from the passed-in colorScheme', () {
      expect(theme.appBarTheme.backgroundColor, testDarkScheme.primary);
      expect(theme.appBarTheme.foregroundColor, testDarkScheme.onPrimary);
    });
  });
}
