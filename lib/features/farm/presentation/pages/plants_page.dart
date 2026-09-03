import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/widgets/related_content_section.dart';
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
    context.read<LandBloc>().add(GetLandsEvent());
    context.read<PlantBloc>().add(GetPlantsEvent());
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<HarvestBloc>().add(GetHarvestsEvent());
    context.read<ContentBloc>().add(GetAllContentEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plants')),
      body: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child:
            BlocSelector<
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
                  return const Center(child: CircularProgressIndicator());
                }

                if (landError) {
                  return const EntityEmptyView(
                    icon: Icons.error_outline,
                    title: 'Could not load data',
                    subtitle: 'Pull down to retry',
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

                            return RefreshIndicator(
                              onRefresh: () async {
                                context.read<LandBloc>().add(GetLandsEvent());
                                context.read<PlantBloc>().add(GetPlantsEvent());
                                context.read<SeasonBloc>().add(
                                  GetSeasonsEvent(),
                                );
                                context.read<HarvestBloc>().add(
                                  GetHarvestsEvent(),
                                );
                                context.read<ContentBloc>().add(
                                  GetAllContentEvent(),
                                );
                              },
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Text(
                                    'Plant Management',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Follow the steps below to set up and manage your crops.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 24),
                                  SetupStepCard(
                                    stepNumber: 1,
                                    title: 'Add Land',
                                    subtitle: 'Register your farmland',
                                    summary: hasLand
                                        ? '$landCount lands registered'
                                        : null,
                                    status: hasLand
                                        ? StepStatus.completed
                                        : StepStatus.available,
                                    onTap: () =>
                                        context.push(AppRoutePath.lands),
                                  ),
                                  StepConnector(isActive: hasLand),
                                  SetupStepCard(
                                    stepNumber: 2,
                                    title: 'Add Plant',
                                    subtitle: 'Register the crops you grow',
                                    summary: hasPlant
                                        ? '$plantCount plants registered'
                                        : null,
                                    status: hasLand
                                        ? (hasPlant
                                              ? StepStatus.completed
                                              : StepStatus.available)
                                        : StepStatus.locked,
                                    onTap: () =>
                                        context.push(AppRoutePath.plants),
                                  ),
                                  StepConnector(isActive: hasPlant),
                                  SetupStepCard(
                                    stepNumber: 3,
                                    title: 'Add Season',
                                    subtitle:
                                        'Track planting and harvesting periods',
                                    summary: hasSeason
                                        ? '$seasonCount seasons created'
                                        : null,
                                    status: hasPlant
                                        ? (hasSeason
                                              ? StepStatus.completed
                                              : StepStatus.available)
                                        : StepStatus.locked,
                                    onTap: () =>
                                        context.push(AppRoutePath.seasons),
                                  ),
                                  StepConnector(isActive: hasSeason),
                                  SetupStepCard(
                                    stepNumber: 4,
                                    title: 'Track Inputs',
                                    subtitle:
                                        'Log fertilizers, seeds, and supplies',
                                    status: hasSeason
                                        ? StepStatus.available
                                        : StepStatus.locked,
                                    onTap: () => context.push(
                                      AppRoutePath.inputsFor('plant'),
                                    ),
                                  ),
                                  const StepConnector(isActive: false),
                                  SetupStepCard(
                                    stepNumber: 5,
                                    title: 'Log Activities',
                                    subtitle:
                                        'Record planting, watering, and more',
                                    status: hasSeason
                                        ? StepStatus.available
                                        : StepStatus.locked,
                                    onTap: () => context.push(
                                      AppRoutePath.activitiesFor('plant'),
                                    ),
                                  ),
                                  StepConnector(isActive: hasSeason),
                                  SetupStepCard(
                                    stepNumber: 6,
                                    title: 'Record Harvest',
                                    subtitle:
                                        'Log yield per season in kg, sacks, and more',
                                    summary: hasHarvest
                                        ? '$harvestCount harvests recorded'
                                        : null,
                                    status: hasSeason
                                        ? (hasHarvest
                                              ? StepStatus.completed
                                              : StepStatus.available)
                                        : StepStatus.locked,
                                    onTap: () =>
                                        context.push(AppRoutePath.harvests),
                                  ),
                                  RelatedContentSection(
                                    matchNames: plantNames,
                                    kind: ContentMatchKind.crop,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
      ),
    );
  }
}
