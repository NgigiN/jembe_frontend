import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm_activity/domain/farm_activity_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 8, 24);

Herd _herd(String id, {DateTime? createdAt}) => Herd(
  id: id,
  userId: 'u',
  name: 'Herd $id',
  animalTypeId: 'a',
  location: 'x',
  initialHeadCount: 1,
  currentHeadCount: 1,
  startDate: _now,
  createdAt: createdAt ?? _now,
  updatedAt: _now,
);

Season _season(String id, {DateTime? createdAt}) => Season(
  id: id,
  userId: 'u',
  name: 'Season $id',
  plantId: 'p',
  landId: 'l',
  startDate: _now,
  createdAt: createdAt ?? _now,
  updatedAt: _now,
);

Activity _activityFor(String sourceType, String sourceId, DateTime createdAt) =>
    Activity(
      id: 'act-${createdAt.toIso8601String()}',
      sourceType: sourceType,
      sourceId: sourceId,
      type: 'x',
      cost: 0,
      date: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

void main() {
  const calculator = FarmActivityCalculator();

  group('freshness scoring boundaries', () {
    test('0-14 days since last activity scores 100 (fresh)', () {
      final herd = _herd('h1', createdAt: _now.subtract(const Duration(days: 100)));
      final activity = _activityFor('animal', 'h1', _now.subtract(const Duration(days: 14)));

      final result = calculator.calculate(
        herds: [herd],
        seasons: const [],
        activities: [activity],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );

      expect(result.score, 100);
      expect(result.level, FarmActivityLevel.thriving);
    });

    test('15 days since last activity scores 60 (aging), not 100', () {
      final herd = _herd('h1', createdAt: _now.subtract(const Duration(days: 100)));
      final activity = _activityFor('animal', 'h1', _now.subtract(const Duration(days: 15)));

      final result = calculator.calculate(
        herds: [herd],
        seasons: const [],
        activities: [activity],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );

      expect(result.score, 60);
    });

    test('30 days scores 60, 31 days scores 30', () {
      final herd = _herd('h1', createdAt: _now.subtract(const Duration(days: 100)));

      final at30 = calculator.calculate(
        herds: [herd],
        seasons: const [],
        activities: [_activityFor('animal', 'h1', _now.subtract(const Duration(days: 30)))],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );
      expect(at30.score, 60);

      final at31 = calculator.calculate(
        herds: [herd],
        seasons: const [],
        activities: [_activityFor('animal', 'h1', _now.subtract(const Duration(days: 31)))],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );
      expect(at31.score, 30);
    });

    test('60 days scores 30, 61 days scores 0 (dormant)', () {
      final herd = _herd('h1', createdAt: _now.subtract(const Duration(days: 100)));

      final at60 = calculator.calculate(
        herds: [herd],
        seasons: const [],
        activities: [_activityFor('animal', 'h1', _now.subtract(const Duration(days: 60)))],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );
      expect(at60.score, 30);

      final at61 = calculator.calculate(
        herds: [herd],
        seasons: const [],
        activities: [_activityFor('animal', 'h1', _now.subtract(const Duration(days: 61)))],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );
      expect(at61.score, 0);
      expect(at61.level, FarmActivityLevel.needsAttention);
    });

    test('a herd with no linked records at all scores 0 (never)', () {
      final result = calculator.calculate(
        herds: [_herd('h1')],
        seasons: const [],
        activities: const [],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );
      expect(result.score, 0);
    });
  });

  group('category scoping', () {
    test('only counting registered categories: pure crop farmer (no herds) is not penalized for herds', () {
      final season = _season('s1');
      final result = calculator.calculate(
        herds: const [],
        seasons: [season],
        activities: [_activityFor('plant', 's1', _now)],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );
      expect(result.score, 100);
      expect(result.level, FarmActivityLevel.thriving);
    });

    test('zero herds and zero seasons yields a null score, not a fabricated 0', () {
      final result = calculator.calculate(
        herds: const [],
        seasons: const [],
        activities: const [],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );
      expect(result.score, isNull);
      expect(result.level, isNull);
    });
  });

  group('weekly streak', () {
    test('an activity in the current (in-progress) week never breaks the streak', () {
      final herd = _herd('h1');
      final result = calculator.calculate(
        herds: [herd],
        seasons: const [],
        activities: [_activityFor('animal', 'h1', _now)],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );
      expect(result.weeklyStreak, 1);
    });

    test(
      'no activity yet this week, but activity last week: streak is preserved, not reset to 0',
      () {
        final herd = _herd('h1');
        final lastWeek = _now.subtract(const Duration(days: 7));
        final result = calculator.calculate(
          herds: [herd],
          seasons: const [],
          activities: [_activityFor('animal', 'h1', lastWeek)],
          inputs: const [],
          harvests: const [],
          revenues: const [],
          now: _now,
        );
        expect(result.weeklyStreak, 1);
      },
    );

    test('a fully elapsed week with nothing recorded ends the streak', () {
      final herd = _herd('h1');
      final thisWeek = _now;
      final threeWeeksAgo = _now.subtract(const Duration(days: 21));
      final result = calculator.calculate(
        herds: [herd],
        seasons: const [],
        // this week and three weeks ago have records; the week in between
        // (one and two weeks ago) has none, so the streak must stop there.
        activities: [
          _activityFor('animal', 'h1', thisWeek),
          _activityFor('animal', 'h1', threeWeeksAgo),
        ],
        inputs: const [],
        harvests: const [],
        revenues: const [],
        now: _now,
      );
      expect(result.weeklyStreak, 1);
    });
  });
}
