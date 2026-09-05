import 'package:farm_tracker/features/farm/domain/entities/farm_year.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FarmYear', () {
    test('January start month behaves like a plain calendar year', () {
      final fy = FarmYear.containing(DateTime(2026, 3, 15), 1);

      expect(fy.startYear, 2026);
      expect(fy.start, DateTime(2026));
      expect(fy.end, DateTime(2027));
      expect(fy.label, '2026');
      expect(fy.rangeLabel, '2026');
    });

    test('a July start month before July falls in the previous fiscal year', () {
      final fy = FarmYear.containing(DateTime(2026, 3, 15), 7);

      expect(fy.startYear, 2025);
      expect(fy.start, DateTime(2025, 7));
      expect(fy.end, DateTime(2026, 7));
      expect(fy.label, '2025/26');
      expect(fy.rangeLabel, 'Jul 2025 – Jun 2026');
    });

    test('a July start month on/after July falls in that calendar year', () {
      final fy = FarmYear.containing(DateTime(2026, 8), 7);

      expect(fy.startYear, 2026);
      expect(fy.label, '2026/27');
      expect(fy.rangeLabel, 'Jul 2026 – Jun 2027');
    });

    test('next/previous shift by exactly one farm-year', () {
      final fy = FarmYear.containing(DateTime(2026, 3, 15), 7);

      expect(fy.next, const FarmYear(startYear: 2026, startMonth: 7));
      expect(fy.previous, const FarmYear(startYear: 2024, startMonth: 7));
    });

    test('canGoNext caps forward navigation at the farm-year containing today', () {
      final now = DateTime(2026, 3, 15);
      final current = FarmYear.containing(now, 7); // 2025/26

      expect(current.canGoNext(now), isFalse);
      expect(current.previous.canGoNext(now), isTrue);
    });
  });
}
