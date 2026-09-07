import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/content/presentation/widgets/related_content_section.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/widgets/setup_step_card.dart';
import 'package:farm_tracker/features/farm/presentation/widgets/step_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PlantsPage extends StatefulWidget {
  const PlantsPage({super.key});

  @override
  State<PlantsPage> createState() => _PlantsPageState();
}

class _PlantsPageState extends State<PlantsPage> {
  @override
  void initState() {
    super.initState();
    // Plant names feed RelatedContentSection below — this fetch stays on
    // BOTH the online and offline path regardless of the dashboard (Phase 8
    // B1: the dashboard returns counts only, never names).
    final plantBloc = context.read<PlantBloc>();
    if (plantBloc.state is! PlantLoaded) {
      if (OfflineConfig.enabled) {
        plantBloc.add(WatchPlantsEvent());
      } else {
        plantBloc.add(GetPlantsEvent());
      }
    }
    final contentBloc = context.read<ContentBloc>();
    if (contentBloc.state is! ContentLoaded) {
      contentBloc.add(GetAllContentEvent());
    }

    if (OfflineConfig.enabled) {
      // Offline: land/season/harvest counts still come from their own
      // fetch/Watch* streams — unchanged from the pre-dashboard behaviour
      // (there is no offline mirror for the dashboard aggregate).
      final landBloc = context.read<LandBloc>();
      if (landBloc.state is! LandLoaded) {
        landBloc.add(GetLandsEvent());
      }
      final seasonBloc = context.read<SeasonBloc>();
      if (seasonBloc.state is! SeasonLoaded) {
        seasonBloc.add(WatchSeasonsEvent());
      }
      final harvestBloc = context.read<HarvestBloc>();
      if (harvestBloc.state is! HarvestLoaded) {
        harvestBloc.add(WatchHarvestsEvent());
      }
    } else {
      // Online: one /dashboard call seeds land/season/harvest counts
      // instead of three separate list GETs fired purely for a count.
      final dashboardBloc = context.read<DashboardBloc>();
      if (dashboardBloc.state is! DashboardLoaded) {
        dashboardBloc.add(GetDashboardEvent());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plants')),
      body: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<PlantBloc>().add(GetPlantsEvent());
            context.read<ContentBloc>().add(GetAllContentEvent());
            if (OfflineConfig.enabled) {
              final landBloc = context.read<LandBloc>()
                ..add(GetLandsEvent());
              context.read<SeasonBloc>().add(GetSeasonsEvent());
              context.read<HarvestBloc>().add(GetHarvestsEvent());
              await landBloc.stream.firstWhere(
                (s) => s is LandLoaded || s is LandError,
              );
            } else {
              final dashboardBloc = context.read<DashboardBloc>()
                ..add(GetDashboardEvent());
              await dashboardBloc.stream.firstWhere(
                (s) => s is DashboardLoaded || s is DashboardError,
              );
            }
          },
          child: OfflineConfig.enabled
              ? _buildOfflineBody(context)
              : _buildOnlineBody(context),
        ),
      ),
    );
  }

  /// Flag ON: land/season/harvest counts sourced from their own blocs,
  /// exactly as before the dashboard existed.
  Widget _buildOfflineBody(BuildContext context) {
    return BlocSelector<
      LandBloc,
      LandState,
      (bool hasLand, int landCount, bool isLoading, bool isError)
    >(
      selector: (state) => (
        state is LandLoaded && state.lands.isNotEmpty,
        state is LandLoaded ? state.lands.length : 0,
        state is LandLoading,
        state is LandError,
      ),
      builder: (context, landInfo) {
        final (hasLand, landCount, landLoading, landError) = landInfo;

        if (!hasLand && landLoading) {
          return _scrollableEmptyState(
            const Center(child: CircularProgressIndicator()),
          );
        }

        if (landError) {
          return _scrollableEmptyState(
            const EntityEmptyView(
              icon: Icons.error_outline,
              title: 'Could not load data',
              subtitle: 'Pull down to retry',
            ),
          );
        }

        return BlocSelector<
          PlantBloc,
          PlantState,
          (bool hasPlant, int plantCount, List<String> plantNames)
        >(
          selector: (state) => (
            state is PlantLoaded && state.plants.isNotEmpty,
            state is PlantLoaded ? state.plants.length : 0,
            state is PlantLoaded
                ? state.plants.map((p) => p.name).toList()
                : const <String>[],
          ),
          builder: (context, plantInfo) {
            final (hasPlant, plantCount, plantNames) = plantInfo;

            return BlocSelector<
              SeasonBloc,
              SeasonState,
              (bool hasSeason, int seasonCount)
            >(
              selector: (state) => (
                state is SeasonLoaded && state.seasons.isNotEmpty,
                state is SeasonLoaded ? state.seasons.length : 0,
              ),
              builder: (context, seasonInfo) {
                final (hasSeason, seasonCount) = seasonInfo;

                return BlocSelector<
                  HarvestBloc,
                  HarvestState,
                  (bool hasHarvest, int harvestCount)
                >(
                  selector: (state) => (
                    state is HarvestLoaded && state.harvests.isNotEmpty,
                    state is HarvestLoaded ? state.harvests.length : 0,
                  ),
                  builder: (context, harvestInfo) {
                    final (hasHarvest, harvestCount) = harvestInfo;

                    return _buildSteps(
                      context,
                      hasLand: hasLand,
                      landCount: landCount,
                      hasPlant: hasPlant,
                      plantCount: plantCount,
                      plantNames: plantNames,
                      hasSeason: hasSeason,
                      seasonCount: seasonCount,
                      hasHarvest: hasHarvest,
                      harvestCount: harvestCount,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Flag OFF (online): land/season/plant/harvest counts sourced from the
  /// dashboard (Phase 8 B3 capped `PlantBloc`'s list fetch at
  /// `kOnlineListPageSize`, so the plant COUNT can no longer come from it
  /// for a >500-plant account — only the dashboard's `counts.plants` is
  /// accurate); plant NAMES still come from `PlantBloc` (Phase 8 B1 — the
  /// dashboard returns counts only, never names). A dashboard fetch
  /// failure degrades gracefully (mirrors `AnimalsPage`'s herd/animal-type
  /// count handling) — counts simply fall back to 0 rather than
  /// hard-blocking the whole screen, so plant names / related content
  /// stay visible even when the dashboard call fails.
  Widget _buildOnlineBody(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, dashboardState) {
        final counts = dashboardState is DashboardLoaded
            ? dashboardState.counts
            : null;

        return BlocSelector<
          PlantBloc,
          PlantState,
          (bool hasPlant, List<String> plantNames)
        >(
          selector: (state) => (
            state is PlantLoaded && state.plants.isNotEmpty,
            state is PlantLoaded
                ? state.plants.map((p) => p.name).toList()
                : const <String>[],
          ),
          builder: (context, plantInfo) {
            final (hasPlant, plantNames) = plantInfo;

            return _buildSteps(
              context,
              hasLand: (counts?.lands ?? 0) > 0,
              landCount: counts?.lands ?? 0,
              hasPlant: hasPlant,
              plantCount: counts?.plants ?? 0,
              plantNames: plantNames,
              hasSeason: (counts?.seasons ?? 0) > 0,
              seasonCount: counts?.seasons ?? 0,
              hasHarvest: (counts?.harvests ?? 0) > 0,
              harvestCount: counts?.harvests ?? 0,
            );
          },
        );
      },
    );
  }

  Widget _buildSteps(
    BuildContext context, {
    required bool hasLand,
    required int landCount,
    required bool hasPlant,
    required int plantCount,
    required List<String> plantNames,
    required bool hasSeason,
    required int seasonCount,
    required bool hasHarvest,
    required int harvestCount,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Plant Management',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Follow the steps below to set up and manage your crops.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        SetupStepCard(
          stepNumber: 1,
          title: 'Add Land',
          subtitle: 'Register your farmland',
          summary: hasLand ? '$landCount lands registered' : null,
          status: hasLand ? StepStatus.completed : StepStatus.available,
          onTap: () => context.push(AppRoutePath.lands),
        ),
        StepConnector(isActive: hasLand),
        SetupStepCard(
          stepNumber: 2,
          title: 'Add Plant',
          subtitle: 'Register the crops you grow',
          summary: hasPlant ? '$plantCount plants registered' : null,
          status: hasLand
              ? (hasPlant ? StepStatus.completed : StepStatus.available)
              : StepStatus.locked,
          onTap: () => context.push(AppRoutePath.plants),
        ),
        StepConnector(isActive: hasPlant),
        SetupStepCard(
          stepNumber: 3,
          title: 'Add Season',
          subtitle: 'Track planting and harvesting periods',
          summary: hasSeason ? '$seasonCount seasons created' : null,
          status: hasPlant
              ? (hasSeason ? StepStatus.completed : StepStatus.available)
              : StepStatus.locked,
          onTap: () => context.push(AppRoutePath.seasons),
        ),
        StepConnector(isActive: hasSeason),
        SetupStepCard(
          stepNumber: 4,
          title: 'Track Inputs',
          subtitle: 'Log fertilizers, seeds, and supplies',
          status: hasSeason ? StepStatus.available : StepStatus.locked,
          onTap: () => context.push(AppRoutePath.inputsFor('plant')),
        ),
        const StepConnector(isActive: false),
        SetupStepCard(
          stepNumber: 5,
          title: 'Log Activities',
          subtitle: 'Record planting, watering, and more',
          status: hasSeason ? StepStatus.available : StepStatus.locked,
          onTap: () => context.push(AppRoutePath.activitiesFor('plant')),
        ),
        StepConnector(isActive: hasSeason),
        SetupStepCard(
          stepNumber: 6,
          title: 'Record Harvest',
          subtitle: 'Log yield per season in kg, sacks, and more',
          summary: hasHarvest ? '$harvestCount harvests recorded' : null,
          status: hasSeason
              ? (hasHarvest ? StepStatus.completed : StepStatus.available)
              : StepStatus.locked,
          onTap: () => context.push(AppRoutePath.harvests),
        ),
        RelatedContentSection(
          matchNames: plantNames,
          kind: ContentMatchKind.crop,
        ),
      ],
    );
  }

  /// Makes a non-scrollable empty/error state (a centered icon+text
  /// column or spinner) pullable: [RefreshIndicator] needs a scrollable
  /// descendant to detect the pull gesture, even when there's nothing to
  /// scroll.
  Widget _scrollableEmptyState(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}
