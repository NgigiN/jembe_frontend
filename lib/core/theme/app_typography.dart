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
}
