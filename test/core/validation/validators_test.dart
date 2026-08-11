import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeText', () {
    test('trims and strips control characters', () {
      expect(sanitizeText('  Green Valley  '), 'Green Valley');
      expect(sanitizeText('Farm\x00Name'), 'FarmName');
    });
  });

  group('requiredName', () {
    test('rejects empty values', () {
      expect(requiredName(''), isNotNull);
      expect(requiredName('   '), isNotNull);
    });

    test('rejects invalid characters', () {
      expect(requiredName('<script>'), isNotNull);
      expect(requiredName('Farm@Home'), isNotNull);
    });

    test('accepts valid names', () {
      expect(requiredName("Ngigi's Farm"), isNull);
      expect(requiredName('Green Valley-2'), isNull);
    });
  });

  group('positiveDecimal', () {
    test('rejects invalid and non-positive values', () {
      expect(positiveDecimal(''), isNotNull);
      expect(positiveDecimal('abc'), isNotNull);
      expect(positiveDecimal('0'), isNotNull);
      expect(positiveDecimal('-5'), isNotNull);
    });

    test('accepts valid decimals', () {
      expect(positiveDecimal('12.5'), isNull);
      expect(positiveDecimal('1'), isNull);
    });
  });

  group('positiveIntMax', () {
    test('enforces maximum', () {
      expect(
        positiveIntMax('10', max: 5, fieldLabel: 'Count'),
        contains('cannot exceed'),
      );
      expect(positiveIntMax('3', max: 5, fieldLabel: 'Count'), isNull);
    });
  });
}