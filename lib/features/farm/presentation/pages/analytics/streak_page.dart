import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm_activity/domain/farm_activity_calculator.dart';
import 'package:farm_tracker/features/farm_activity/presentation/farm_activity_level_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StreakPage extends StatefulWidget {
  const StreakPage({this.now, super.key});

  /// Overridable for tests; defaults to the real current time.
  final DateTime? now;

  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> {
  FarmActivityLevel? _previousLevel;

  @override
  Widget build(BuildContext context) {
    final herds = context.watch<HerdBloc>().state.herds;
    final seasons = context.watch<SeasonBloc>().state.seasons;
    final activities = context.watch<ActivityBloc>().state.activities;
    final inputs = context.watch<InputBloc>().state.inputs;
    final harvests = context.watch<HarvestBloc>().state.harvests;
    final revenues = context.watch<RevenueBloc>().state.revenues;

    const calculator = FarmActivityCalculator();
    final result = calculator.calculate(
      herds: herds,
      seasons: seasons,
      activities: activities,
      inputs: inputs,
      harvests: harvests,
      revenues: revenues,
      now: widget.now,
    );

    final level = result.level;

    if (level == FarmActivityLevel.thriving &&
        _previousLevel != FarmActivityLevel.thriving) {
      SuccessFeedback.thriving();
    }
    _previousLevel = level;

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Activity Streak')),
      body: level == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nothing to track yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildLevelHeader(context, level),
                if (result.weeklyStreak > 0) ...[
                  const SizedBox(height: 16),
                  _buildStreakCallout(context, result.weeklyStreak),
                ],
                const SizedBox(height: 24),
                Text(
                  'Herd & season activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in result.breakdown)
                  _buildBreakdownItem(context, entry),
              ],
            ),
    );
  }

  Widget _buildLevelHeader(BuildContext context, FarmActivityLevel level) {
    final color = farmActivityColorFor(context, level);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(farmActivityIconFor(level), color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmActivityLabelFor(level),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(farmActivityExplanationFor(level)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCallout(BuildContext context, int weeklyStreak) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.statusColors.positive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$weeklyStreak-week streak',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "You've logged something every week for the last "
                  '$weeklyStreak week${weeklyStreak == 1 ? '' : 's'} - keep it up!',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(BuildContext context, EnterpriseFreshness entry) {
    final days = entry.daysSinceLastActivity;
    final isFresh = days != null && days <= 14;
    final String statusText;
    if (days == null) {
      statusText = 'No activity yet';
    } else if (isFresh) {
      statusText = days == 0
          ? 'Active today'
          : 'Active $days day${days == 1 ? '' : 's'} ago';
    } else {
      statusText = 'No activity in $days days';
    }
    final statusColor = days == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (isFresh
              ? context.statusColors.positive
              : context.statusColors.negative);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(entry.isHerd ? Icons.pets : Icons.grass),
        title: Text(entry.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFresh ? Icons.check_circle : Icons.warning_amber,
              color: statusColor,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(statusText, style: TextStyle(color: statusColor)),
          ],
        ),
      ),
    );
  }
}
