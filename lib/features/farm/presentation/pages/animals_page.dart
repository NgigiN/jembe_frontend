import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/content/presentation/widgets/related_content_section.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/widgets/setup_step_card.dart';
import 'package:farm_tracker/features/farm/presentation/widgets/step_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AnimalsPage extends StatefulWidget {
  const AnimalsPage({super.key});

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  @override
  void initState() {
    super.initState();
    // Animal-type names feed RelatedContentSection below — this fetch stays
    // regardless of the dashboard (Phase 8 B1: the dashboard returns counts
    // only, never names).
    final animalTypeBloc = context.read<AnimalTypeBloc>();
    if (animalTypeBloc.state is! AnimalTypeLoaded) {
      animalTypeBloc.add(GetAnimalTypesEvent());
    }
    final contentBloc = context.read<ContentBloc>();
    if (contentBloc.state is! ContentLoaded) {
      contentBloc.add(GetAllContentEvent());
    }

    if (OfflineConfig.enabled) {
      // Offline: herd count still comes from HerdBloc's own fetch —
      // unchanged from the pre-dashboard behaviour (there is no offline
      // mirror for the dashboard aggregate).
      final herdBloc = context.read<HerdBloc>();
      if (herdBloc.state is! HerdLoaded) {
        herdBloc.add(GetHerdsEvent());
      }
    } else {
      // Online: one /dashboard call seeds the herd count instead of a
      // second list GET fired purely for a count.
      final dashboardBloc = context.read<DashboardBloc>();
      if (dashboardBloc.state is! DashboardLoaded) {
        dashboardBloc.add(GetDashboardEvent());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals'),
      ),
      body: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: RefreshIndicator(
          onRefresh: () async {
            final animalTypeBloc = context.read<AnimalTypeBloc>()
              ..add(GetAnimalTypesEvent());
            context.read<ContentBloc>().add(GetAllContentEvent());
            if (OfflineConfig.enabled) {
              context.read<HerdBloc>().add(GetHerdsEvent());
            } else {
              context.read<DashboardBloc>().add(GetDashboardEvent());
            }
            await animalTypeBloc.stream.firstWhere(
              (s) => s is AnimalTypeLoaded || s is AnimalTypeError,
            );
          },
          child: BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
          builder: (context, animalTypeState) {
            final hasAnimalType = animalTypeState is AnimalTypeLoaded &&
                animalTypeState.animalTypes.isNotEmpty;
            final animalTypeNames = animalTypeState is AnimalTypeLoaded
                ? animalTypeState.animalTypes.map((t) => t.name).toList()
                : const <String>[];

            if (!hasAnimalType && animalTypeState is AnimalTypeLoading) {
              return _scrollableEmptyState(
                const Center(child: CircularProgressIndicator()),
              );
            }

            if (animalTypeState is AnimalTypeError) {
              return _scrollableEmptyState(
                const EntityEmptyView(
                  icon: Icons.error_outline,
                  title: 'Could not load data',
                  subtitle: 'Pull down to retry',
                ),
              );
            }

            // Flag ON: herd count AND animal-type count sourced from their
            // own blocs, exactly as before the dashboard existed. Flag OFF
            // (online): both counts sourced from the dashboard instead of
            // list GETs fired purely for a count — the dashboard fetch
            // failing degrades gracefully (counts fall back to 0) rather
            // than hard-blocking the screen, since animal-type NAMES /
            // related content already loaded fine from AnimalTypeBloc.
            return OfflineConfig.enabled
                ? BlocBuilder<HerdBloc, HerdState>(
                    builder: (context, herdState) {
                      final hasHerd = herdState is HerdLoaded &&
                          herdState.herds.isNotEmpty;
                      final herdCount = herdState is HerdLoaded
                          ? herdState.herds.length
                          : 0;
                      final animalTypeCount = animalTypeState is AnimalTypeLoaded
                          ? animalTypeState.animalTypes.length
                          : 0;

                      return _buildSteps(
                        context,
                        hasAnimalType: hasAnimalType,
                        animalTypeCount: animalTypeCount,
                        animalTypeNames: animalTypeNames,
                        hasHerd: hasHerd,
                        herdCount: herdCount,
                      );
                    },
                  )
                : BlocBuilder<DashboardBloc, DashboardState>(
                    builder: (context, dashboardState) {
                      final counts = dashboardState is DashboardLoaded
                          ? dashboardState.counts
                          : null;
                      final herdCount = counts?.herds ?? 0;
                      final animalTypeCount = counts?.animalTypes ?? 0;

                      return _buildSteps(
                        context,
                        hasAnimalType: hasAnimalType,
                        animalTypeCount: animalTypeCount,
                        animalTypeNames: animalTypeNames,
                        hasHerd: herdCount > 0,
                        herdCount: herdCount,
                      );
                    },
                  );
          },
          ),
        ),
      ),
    );
  }

  Widget _buildSteps(
    BuildContext context, {
    required bool hasAnimalType,
    required int animalTypeCount,
    required List<String> animalTypeNames,
    required bool hasHerd,
    required int herdCount,
  }) {
    return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Animal Management',
            style:
                Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Follow the steps below to set up and manage your livestock.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          SetupStepCard(
            stepNumber: 1,
            title: 'Add Animal Types',
            subtitle: 'Define the types of animals you keep',
            summary: hasAnimalType
                ? '$animalTypeCount types added'
                : null,
            status: hasAnimalType
                ? StepStatus.completed
                : StepStatus.available,
            onTap: () =>
                context.push(AppRoutePath.animalTypes),
          ),
          StepConnector(isActive: hasAnimalType),
          SetupStepCard(
            stepNumber: 2,
            title: 'Register Herd',
            subtitle: 'Create herds with location tracking',
            summary: hasHerd
                ? '$herdCount herds registered'
                : null,
            status: hasAnimalType
                ? (hasHerd
                    ? StepStatus.completed
                    : StepStatus.available)
                : StepStatus.locked,
            onTap: () =>
                context.push(AppRoutePath.herds),
          ),
          StepConnector(isActive: hasHerd),
          SetupStepCard(
            stepNumber: 3,
            title: 'Record Herd Events',
            subtitle: 'Log births and fatalities to update headcount',
            status: hasHerd
                ? StepStatus.available
                : StepStatus.locked,
            onTap: () =>
                context.push(AppRoutePath.herdActivities),
          ),
          StepConnector(isActive: hasHerd),
          SetupStepCard(
            stepNumber: 4,
            title: 'Track Inputs',
            subtitle: 'Log feed, medicine, and supplies',
            status: hasHerd
                ? StepStatus.available
                : StepStatus.locked,
            onTap: () => context.push(
                AppRoutePath.inputsFor('animal')),
          ),
          const StepConnector(isActive: false),
          SetupStepCard(
            stepNumber: 5,
            title: 'Log Activities',
            subtitle: 'Record health checks, breeding, and more',
            status: hasHerd
                ? StepStatus.available
                : StepStatus.locked,
            onTap: () => context.push(
                AppRoutePath.activitiesFor('animal')),
          ),
          StepConnector(isActive: hasAnimalType),
          SetupStepCard(
            stepNumber: 6,
            title: 'Manage Infrastructure',
            subtitle: 'Track barns, fences, stores, and other assets',
            status: hasAnimalType
                ? StepStatus.available
                : StepStatus.locked,
            onTap: () =>
                context.push(AppRoutePath.infrastructure),
          ),
          StepConnector(isActive: hasHerd),
          SetupStepCard(
            stepNumber: 7,
            title: 'Track Individual Animals',
            subtitle: 'Record details for each animal in your herds',
            status: hasHerd
                ? StepStatus.available
                : StepStatus.locked,
            onTap: () =>
                context.push(AppRoutePath.animalsList),
          ),
          RelatedContentSection(
            matchNames: animalTypeNames,
            kind: ContentMatchKind.animal,
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
