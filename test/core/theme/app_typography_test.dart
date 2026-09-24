import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTypography font-family assignment', () {
    late final textTheme = AppTypography.getTextTheme();

    test('display roles use Fraunces', () {
      expect(textTheme.displayLarge!.fontFamily, 'Fraunces');
      expect(textTheme.displayMedium!.fontFamily, 'Fraunces');
      expect(textTheme.displaySmall!.fontFamily, 'Fraunces');
      expect(textTheme.headlineMedium!.fontFamily, 'Fraunces');
      expect(textTheme.titleLarge!.fontFamily, 'Fraunces');
    });

    test('body/label roles use Work Sans', () {
      expect(textTheme.titleMedium!.fontFamily, 'WorkSans');
      expect(textTheme.bodyLarge!.fontFamily, 'WorkSans');
      expect(textTheme.bodyMedium!.fontFamily, 'WorkSans');
      expect(textTheme.bodySmall!.fontFamily, 'WorkSans');
      expect(textTheme.labelLarge!.fontFamily, 'WorkSans');
      expect(textTheme.labelSmall!.fontFamily, 'WorkSans');
    });
  });
}
