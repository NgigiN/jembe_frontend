import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm_activity/domain/farm_activity_calculator.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FarmActivityCard extends StatefulWidget {
  const FarmActivityCard({super.key});

  @override
  State<FarmActivityCard> createState() => _FarmActivityCardState();
}

class _FarmActivityCardState extends State<FarmActivityCard> {
  @override
  void initState() {
    super.initState();
    context.read<HerdBloc>().add(GetHerdsEvent());
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<ActivityBloc>().add(GetActivitiesEvent());
    context.read<InputBloc>().add(GetInputsEvent());
    context.read<HarvestBloc>().add(GetHarvestsEvent());
    context.read<RevenueBloc>().add(LoadRevenues());
    sl<AnalyticsService>().track('farm_activity_viewed');
  }

  @override
  Widget build(BuildContext context) {
    final herdState = context.watch<HerdBloc>().state;
    final seasonState = context.watch<SeasonBloc>().state;
    final activityState = context.watch<ActivityBloc>().state;
    final inputState = context.watch<InputBloc>().state;
    final harvestState = context.watch<HarvestBloc>().state;
    final revenueState = context.watch<RevenueBloc>().state;

    final anyUnsettled =
        herdState is HerdInitial ||
        herdState is HerdLoading ||
        seasonState is SeasonInitial ||
        seasonState is SeasonLoading ||
        activityState is ActivityInitial ||
        activityState is ActivityLoading ||
        inputState is InputInitial ||
        inputState is InputLoading ||
        harvestState is HarvestInitial ||
        harvestState is HarvestLoading ||
        revenueState is RevenueInitial ||
        revenueState is RevenueLoading;

    final anyError =
        herdState is HerdError ||
        seasonState is SeasonError ||
        activityState is ActivityError ||
        inputState is InputError ||
        harvestState is HarvestError ||
        revenueState is RevenueError;

    if (anyUnsettled || anyError) {
      return const SizedBox.shrink();
    }

    final herds = herdState.herds;
    final seasons = seasonState.seasons;
    final activities = activityState.activities;
    final inputs = inputState.inputs;
    final harvests = harvestState.harvests;
    final revenues = revenueState.revenues;

    const calculator = FarmActivityCalculator();
    final result = calculator.calculate(
      herds: herds,
      seasons: seasons,
      activities: activities,
      inputs: inputs,
      harvests: harvests,
      revenues: revenues,
    );

    final level = result.level;
    if (level == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(_iconFor(level), color: _colorFor(level), size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelFor(level),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (result.weeklyStreak > 0)
                    Text(
                      '${result.weeklyStreak}-week streak',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(FarmActivityLevel level) => switch (level) {
    FarmActivityLevel.thriving => Icons.eco,
    FarmActivityLevel.onTrack => Icons.trending_up,
    FarmActivityLevel.needsAttention => Icons.warning_amber,
  };

  Color _colorFor(FarmActivityLevel level) => switch (level) {
    FarmActivityLevel.thriving => Colors.green,
    FarmActivityLevel.onTrack => Colors.orange,
    FarmActivityLevel.needsAttention => Colors.red,
  };

  String _labelFor(FarmActivityLevel level) => switch (level) {
    FarmActivityLevel.thriving => 'Thriving',
    FarmActivityLevel.onTrack => 'On track',
    FarmActivityLevel.needsAttention => 'Needs attention',
  };
}
