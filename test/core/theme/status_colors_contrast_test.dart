import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WCAG 2.1 contrast ratio: https://www.w3.org/TR/WCAG21/#contrast-minimum
// (lighter luminance + 0.05) / (darker luminance + 0.05). AA for normal text
// is 4.5:1. Color.computeLuminance() implements the same relative-luminance
// formula WCAG specifies, so this needs no external library.
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('StatusColors meet WCAG AA against their theme surface', () {
    test('light status colors are readable on the light surface', () {
      final surface = AppColors.lightColorScheme.surface;
      expect(_contrastRatio(AppColors.statusPositiveLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.statusWarningLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.statusNegativeLight, surface), greaterThanOrEqualTo(4.5));
    });

    test('dark status colors are readable on the dark surface', () {
      final surface = AppColors.darkColorScheme.surface;
      expect(_contrastRatio(AppColors.statusPositiveDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.statusWarningDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.statusNegativeDark, surface), greaterThanOrEqualTo(4.5));
    });
  });
}
