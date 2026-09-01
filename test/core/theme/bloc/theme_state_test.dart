import 'package:farm_tracker/core/theme/bloc/theme_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial state follows the system theme', () {
    expect(ThemeState.initial().themeMode, ThemeMode.system);
  });

  group('isDarkMode', () {
    test('is true when explicitly set to dark, regardless of platform', () {
      const state = ThemeState(themeMode: ThemeMode.dark);
      expect(state.isDarkMode(Brightness.light), isTrue);
      expect(state.isDarkMode(Brightness.dark), isTrue);
    });

    test('is false when explicitly set to light, regardless of platform', () {
      const state = ThemeState(themeMode: ThemeMode.light);
      expect(state.isDarkMode(Brightness.light), isFalse);
      expect(state.isDarkMode(Brightness.dark), isFalse);
    });

    test('follows the platform brightness when set to system', () {
      const state = ThemeState(themeMode: ThemeMode.system);
      expect(state.isDarkMode(Brightness.light), isFalse);
      expect(state.isDarkMode(Brightness.dark), isTrue);
    });
  });
}
