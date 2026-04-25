import 'package:flutter/material.dart';

class ThemeState {
  const ThemeState({required this.themeMode});

  factory ThemeState.initial() {
    return const ThemeState(themeMode: ThemeMode.light);
  }
  final ThemeMode themeMode;

  bool get isDarkMode => themeMode == ThemeMode.dark;
}
