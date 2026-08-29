import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/utils/source_context_resolver.dart';

class AnimalPage extends StatefulWidget {
  const AnimalPage({super.key});

  @override
  State<AnimalPage> createState() => _AnimalPageState();
}

class _AnimalPageState extends State<AnimalPage> {
  @override
  void initState() {
    super.initState();
    context.read<AnimalBloc>().add(GetAnimalsEvent());
    context.read<AnimalTypeBloc>().add(GetAnimalTypesEvent());
    context.read<HerdBloc>().add(GetHerdsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final animalTypeState = context.watch<AnimalTypeBloc>().state;
    final animalTypes = animalTypeState.animalTypes;
    final herdState = context.watch<HerdBloc>().state;
    final herds = herdState.herds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<AnimalBloc, AnimalState>(
        listener: (context, state) {
          if (state is AnimalLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(state.successMessage!),
            );
          } else if (state is AnimalError && state.animals.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is AnimalLoading && state.animals.isEmpty) {
            return const SkeletonEntityList(icon: Icons.pets);
          }

          if (state is AnimalError && state.animals.isEmpty) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<AnimalBloc>().add(GetAnimalsEvent()),
            );
          }

          final animals = state.animals;
          if (animals.isEmpty) {
            return EntityEmptyView(
              icon: Icons.pets,
              title: 'No animals registered yet',
              subtitle: 'Tap the + button to add your first animal',
            );
          }

          return ListView.builder(
            padding: context.scrollListPadding(forFab: true),
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];
              return EntityCard(
                icon: Icons.pets,
                iconColor: AppColors.animalCategory,
                title: animal.name,
                subtitle: _animalSubtitle(animal, animalTypes, herds),
                onTap: () {},
              );
            },
          );
        },
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _animalSubtitle(Animal animal, List<AnimalType> animalTypes, List<Herd> herds) {
    return '${animalTypeName(animalTypes, animal.animalTypeId)} · ${herdName(herds, animal.herdId)}';
  }
}
