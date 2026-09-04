import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/content/presentation/widgets/related_content_section.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
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
    final animalTypeBloc = context.read<AnimalTypeBloc>();
    if (animalTypeBloc.state is! AnimalTypeLoaded) {
      animalTypeBloc.add(GetAnimalTypesEvent());
    }
    final herdBloc = context.read<HerdBloc>();
    if (herdBloc.state is! HerdLoaded) {
      herdBloc.add(GetHerdsEvent());
    }
    final contentBloc = context.read<ContentBloc>();
    if (contentBloc.state is! ContentLoaded) {
      contentBloc.add(GetAllContentEvent());
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
            context.read<HerdBloc>().add(GetHerdsEvent());
            context.read<ContentBloc>().add(GetAllContentEvent());
            await animalTypeBloc.stream.firstWhere(
              (s) => s is AnimalTypeLoaded || s is AnimalTypeError,
            );
          },
          child: BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
          builder: (context, animalTypeState) {
            final hasAnimalType = animalTypeState is AnimalTypeLoaded &&
                animalTypeState.animalTypes.isNotEmpty;
            final animalTypeCount = animalTypeState is AnimalTypeLoaded
                ? animalTypeState.animalTypes.length
                : 0;
            final animalTypeNames = animalTypeState is AnimalTypeLoaded
                ? animalTypeState.animalTypes.map((t) => t.name).toList()
                : const <String>[];

            return BlocBuilder<HerdBloc, HerdState>(
              builder: (context, herdState) {
                final hasHerd =
                    herdState is HerdLoaded && herdState.herds.isNotEmpty;
                final herdCount =
                    herdState is HerdLoaded ? herdState.herds.length : 0;

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
              },
            );
          },
          ),
        ),
      ),
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
