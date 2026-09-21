import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money() adds tabular-figures to the given style without altering other fields', () {
    const base = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black);
    final result = AppTypography.money(base);

    expect(result.fontSize, base.fontSize);
    expect(result.fontWeight, base.fontWeight);
    expect(result.color, base.color);
    expect(result.fontFeatures, contains(const FontFeature.tabularFigures()));
  });
}
