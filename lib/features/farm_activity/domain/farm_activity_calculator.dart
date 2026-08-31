import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';

enum FarmActivityLevel { thriving, onTrack, needsAttention }

class FarmActivityResult {
  const FarmActivityResult({
    required this.score,
    required this.level,
    required this.weeklyStreak,
    required this.breakdown,
  });

  /// Null when the farmer has zero herds and zero seasons - there is
  /// nothing to score yet, and that's not the same as a 0.
  final int? score;
  final FarmActivityLevel? level;
  final int weeklyStreak;

  /// One entry per herd/season, sorted stalest-first (never-active first,
  /// then oldest to freshest), for surfacing exactly what's dragging the
  /// score down.
  final List<EnterpriseFreshness> breakdown;
}

class EnterpriseFreshness {
  const EnterpriseFreshness({
    required this.name,
    required this.isHerd,
    required this.daysSinceLastActivity,
  });

  final String name;
  final bool isHerd;

  /// Null when there is no recorded activity/input/harvest/revenue at all.
  final int? daysSinceLastActivity;
}

/// Pure, deterministic, no-ML computation over data already loaded
/// elsewhere in the app. See the design spec's "Farm-health score +
/// streak" section for the exact bucket cutoffs this mirrors (renamed
/// to "Farm Activity Score" post-implementation - this measures
/// record-keeping freshness/cadence, not animal or crop health).
class FarmActivityCalculator {
  const FarmActivityCalculator();

  FarmActivityResult calculate({
    required List<Herd> herds,
    required List<Season> seasons,
    required List<Activity> activities,
    required List<Input> inputs,
    required List<Harvest> harvests,
    required List<Revenue> revenues,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();

    final herdMostRecent = <String, DateTime?>{
      for (final herd in herds)
        herd.id: _mostRecentForHerd(herd.id, activities, inputs, revenues),
    };
    final seasonMostRecent = <String, DateTime?>{
      for (final season in seasons)
        season.id: _mostRecentForSeason(
          season.id,
          activities,
          inputs,
          harvests,
          revenues,
        ),
    };

    final scores = <int>[
      for (final mostRecent in herdMostRecent.values)
        _freshnessScore(mostRecent, effectiveNow),
      for (final mostRecent in seasonMostRecent.values)
        _freshnessScore(mostRecent, effectiveNow),
    ];

    int? averageScore;
    FarmActivityLevel? level;
    if (scores.isNotEmpty) {
      averageScore = (scores.reduce((a, b) => a + b) / scores.length).round();
      level = _levelFor(averageScore);
    }

    final streak = _weeklyStreak(
      activities: activities,
      inputs: inputs,
      harvests: harvests,
      revenues: revenues,
      now: effectiveNow,
    );

    final breakdown = <EnterpriseFreshness>[
      for (final herd in herds)
        EnterpriseFreshness(
          name: herd.name,
          isHerd: true,
          daysSinceLastActivity: _daysSince(herdMostRecent[herd.id], effectiveNow),
        ),
      for (final season in seasons)
        EnterpriseFreshness(
          name: season.name,
          isHerd: false,
          daysSinceLastActivity: _daysSince(
            seasonMostRecent[season.id],
            effectiveNow,
          ),
        ),
    ]..sort(_stalestFirst);

    return FarmActivityResult(
      score: averageScore,
      level: level,
      weeklyStreak: streak,
      breakdown: breakdown,
    );
  }

  int? _daysSince(DateTime? mostRecent, DateTime now) {
    if (mostRecent == null) return null;
    return now.difference(mostRecent).inDays;
  }

  /// Never-active (null) sorts first, then oldest to freshest.
  int _stalestFirst(EnterpriseFreshness a, EnterpriseFreshness b) {
    final aDays = a.daysSinceLastActivity;
    final bDays = b.daysSinceLastActivity;
    if (aDays == null && bDays == null) return 0;
    if (aDays == null) return -1;
    if (bDays == null) return 1;
    return bDays.compareTo(aDays);
  }

  DateTime? _mostRecentForHerd(
    String herdId,
    List<Activity> activities,
    List<Input> inputs,
    List<Revenue> revenues,
  ) {
    final dates = <DateTime>[
      for (final a in activities)
        if (a.sourceType == 'animal' && a.sourceId == herdId) a.createdAt,
      for (final i in inputs)
        if (i.sourceType == 'animal' && i.sourceId == herdId) i.createdAt,
      for (final r in revenues)
        if (r.source == 'animal' && r.sourceId == herdId) r.createdAt,
    ];
    return _latest(dates);
  }

  DateTime? _mostRecentForSeason(
    String seasonId,
    List<Activity> activities,
    List<Input> inputs,
    List<Harvest> harvests,
    List<Revenue> revenues,
  ) {
    final dates = <DateTime>[
      for (final a in activities)
        if (a.sourceType == 'plant' && a.sourceId == seasonId) a.createdAt,
      for (final i in inputs)
        if (i.sourceType == 'plant' && i.sourceId == seasonId) i.createdAt,
      for (final h in harvests)
        if (h.seasonId == seasonId) h.createdAt,
      for (final r in revenues)
        if (r.source == 'plant' && r.sourceId == seasonId) r.createdAt,
    ];
    return _latest(dates);
  }

  DateTime? _latest(List<DateTime> dates) {
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  int _freshnessScore(DateTime? mostRecent, DateTime now) {
    if (mostRecent == null) return 0;
    final days = now.difference(mostRecent).inDays;
    if (days <= 14) return 100;
    if (days <= 30) return 60;
    if (days <= 60) return 30;
    return 0;
  }

  FarmActivityLevel _levelFor(int score) {
    if (score >= 70) return FarmActivityLevel.thriving;
    if (score >= 35) return FarmActivityLevel.onTrack;
    return FarmActivityLevel.needsAttention;
  }

  /// Consecutive weeks, walking backward from the current week, that have
  /// at least one recorded activity/input/harvest/revenue.
  ///
  /// Only actual recorded events count toward a week "having activity" -
  /// deliberately not `Herd.createdAt` / `Season.createdAt` (registering a
  /// herd or season is not itself an activity, and counting it here would
  /// let a brand-new registration masquerade as "activity this week").
  ///
  /// The current, still-in-progress week is exempt from ending the streak
  /// even when it has zero records so far: only a *fully elapsed* week
  /// with nothing recorded breaks the chain. When the current week *does*
  /// already have a record, that week counts toward the streak just like
  /// any other week - it is not merely exempted from breaking it.
  int _weeklyStreak({
    required List<Activity> activities,
    required List<Input> inputs,
    required List<Harvest> harvests,
    required List<Revenue> revenues,
    required DateTime now,
  }) {
    final allDates = <DateTime>[
      for (final a in activities) a.createdAt,
      for (final i in inputs) i.createdAt,
      for (final h in harvests) h.createdAt,
      for (final r in revenues) r.createdAt,
    ];
    if (allDates.isEmpty) return 0;

    var streak = 0;
    var weekStart = _startOfWeek(now);
    var isCurrentWeek = true;
    final oldest = allDates.reduce((a, b) => a.isBefore(b) ? a : b);

    while (true) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final hasRecordThisWeek = allDates.any(
        (d) => !d.isBefore(weekStart) && d.isBefore(weekEnd),
      );

      if (hasRecordThisWeek) {
        streak++;
      } else if (!isCurrentWeek) {
        // A fully elapsed week with nothing recorded ends the streak.
        // The current, still-in-progress week gets a pass even with
        // zero records so far - see method doc comment.
        break;
      }

      weekStart = weekStart.subtract(const Duration(days: 7));
      isCurrentWeek = false;

      // Safety bound: never walk further back than the oldest record.
      if (weekStart.isBefore(oldest)) {
        break;
      }
    }

    return streak;
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }
}
