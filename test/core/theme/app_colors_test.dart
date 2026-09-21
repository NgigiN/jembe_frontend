import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors seed-based schemes', () {
    test('brandSeed is the exact marketing-site green', () {
      expect(AppColors.brandSeed, const Color(0xFF2E7D32));
    });

    test('lightColorScheme uses the brand seed as primary', () {
      expect(AppColors.lightColorScheme.brightness, Brightness.light);
      expect(AppColors.lightColorScheme.primary, AppColors.brandSeed);
    });

    test('lightColorScheme pins the exact marketing-site surface and text', () {
      expect(AppColors.lightColorScheme.surface, const Color(0xFFF6F7F4));
      expect(AppColors.lightColorScheme.onSurface, const Color(0xFF111511));
    });

    test('darkColorScheme is generated from the same seed hue, not the exact light primary', () {
      // Dark mode deliberately does NOT pin primary to the literal brandSeed
      // hex (see app_colors.dart) - M3 uses a lighter tone of the same hue
      // against a dark surface for legibility. Assert it is a DIFFERENT,
      // lighter shade sharing the same green hue family, not an unrelated
      // color and not a byte-identical copy of the light primary.
      expect(AppColors.darkColorScheme.brightness, Brightness.dark);
      expect(AppColors.darkColorScheme.primary, isNot(AppColors.brandSeed));
      final hsl = HSLColor.fromColor(AppColors.darkColorScheme.primary);
      final seedHsl = HSLColor.fromColor(AppColors.brandSeed);
      expect((hsl.hue - seedHsl.hue).abs(), lessThan(15), reason: 'same green hue family');
      expect(hsl.lightness, greaterThan(seedHsl.lightness), reason: 'lighter tone for dark-surface legibility');
    });

    test('light and dark schemes are not identical (seeded generation actually ran)', () {
      expect(AppColors.lightColorScheme.surface, isNot(AppColors.darkColorScheme.surface));
    });
  });
}
