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
import 'package:farm_tracker/features/farm_health/domain/farm_health_calculator.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FarmHealthCard extends StatefulWidget {
  const FarmHealthCard({super.key});

  @override
  State<FarmHealthCard> createState() => _FarmHealthCardState();
}

class _FarmHealthCardState extends State<FarmHealthCard> {
  @override
  void initState() {
    super.initState();
    context.read<HerdBloc>().add(GetHerdsEvent());
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<ActivityBloc>().add(GetActivitiesEvent());
    context.read<InputBloc>().add(GetInputsEvent());
    context.read<HarvestBloc>().add(GetHarvestsEvent());
    context.read<RevenueBloc>().add(LoadRevenues());
    sl<AnalyticsService>().track('farm_health_viewed');
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

    const calculator = FarmHealthCalculator();
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

  IconData _iconFor(FarmHealthLevel level) => switch (level) {
    FarmHealthLevel.thriving => Icons.eco,
    FarmHealthLevel.onTrack => Icons.trending_up,
    FarmHealthLevel.needsAttention => Icons.warning_amber,
  };

  Color _colorFor(FarmHealthLevel level) => switch (level) {
    FarmHealthLevel.thriving => Colors.green,
    FarmHealthLevel.onTrack => Colors.orange,
    FarmHealthLevel.needsAttention => Colors.red,
  };

  String _labelFor(FarmHealthLevel level) => switch (level) {
    FarmHealthLevel.thriving => 'Thriving',
    FarmHealthLevel.onTrack => 'On track',
    FarmHealthLevel.needsAttention => 'Needs attention',
  };
}
