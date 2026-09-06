import 'package:farm_tracker/core/utils/json_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDate', () {
    test('parses a valid ISO-8601 string', () {
      expect(
        parseDate('2026-08-01T00:00:00Z'),
        DateTime.parse('2026-08-01T00:00:00Z'),
      );
    });

    test('falls back to now for null', () {
      final before = DateTime.now();
      final result = parseDate(null);
      final after = DateTime.now();
      expect(
        result.isAfter(before.subtract(const Duration(seconds: 1))) &&
            result.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('falls back to now for a non-string value', () {
      expect(parseDate(1234), isA<DateTime>());
    });

    test(
      'falls back to now (rather than throwing) for a malformed string — '
      'the tolerant semantics R2-01 standardized on',
      () {
        expect(() => parseDate('not-a-date'), returnsNormally);
        expect(parseDate('not-a-date'), isA<DateTime>());
      },
    );
  });

  group('parseInt', () {
    test('passes through an int', () => expect(parseInt(5), 5));
    test('truncates a double', () => expect(parseInt(5.9), 5));
    test('parses a numeric string', () => expect(parseInt('7'), 7));
    test(
      'falls back to 0 for null or an unparseable string',
      () {
        expect(parseInt(null), 0);
        expect(parseInt('nope'), 0);
      },
    );
  });

  group('parseDouble', () {
    test('passes through a double', () => expect(parseDouble(5.5), 5.5));
    test('widens an int', () => expect(parseDouble(5), 5.0));
    test('parses a numeric string', () => expect(parseDouble('7.5'), 7.5));
    test(
      'falls back to 0 for null or an unparseable string',
      () {
        expect(parseDouble(null), 0.0);
        expect(parseDouble('nope'), 0.0);
      },
    );
  });

  group('dualKey', () {
    test('prefers the PascalCase form when present', () {
      final json = {'CreatedAt': 'pascal', 'created_at': 'snake'};
      expect(dualKey(json, 'created_at'), 'pascal');
    });

    test('falls back to the snake_case form', () {
      final json = {'created_at': 'snake'};
      expect(dualKey(json, 'created_at'), 'snake');
    });

    test('derives a multi-word PascalCase key', () {
      final json = {'AnimalTypeID': 'value'};
      expect(dualKey(json, 'animal_type_i_d'), 'value');
    });

    test('returns null when neither key is present', () {
      expect(dualKey(const {}, 'created_at'), isNull);
    });
  });
}
