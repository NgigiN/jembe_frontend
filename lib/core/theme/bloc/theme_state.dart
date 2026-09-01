import 'package:flutter/material.dart';

class ThemeState {
  const ThemeState({required this.themeMode});

  factory ThemeState.initial() {
    return const ThemeState(themeMode: ThemeMode.system);
  }
  final ThemeMode themeMode;

  /// Resolves whether the effective theme is dark, given the platform's
  /// current brightness - needed because [themeMode] can be
  /// [ThemeMode.system], which has no fixed answer on its own.
  bool isDarkMode(Brightness platformBrightness) {
    return switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
  }
}
