import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_list_tile.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';

class HerdPage extends StatefulWidget {
  const HerdPage({super.key});

  @override
  State<HerdPage> createState() => _HerdPageState();
}

class _HerdPageState extends State<HerdPage> {
  @override
  void initState() {
    super.initState();
    context.read<HerdBloc>().add(GetHerdsEvent());
    context.read<AnimalTypeBloc>().add(GetAnimalTypesEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Herd Management'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<HerdBloc, HerdState>(
        builder: (context, state) {
          if (state is HerdLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HerdError) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<HerdBloc>().add(GetHerdsEvent()),
            );
          }

          if (state is HerdLoaded) {
            if (state.herds.isEmpty) {
              return EntityEmptyView(
                icon: Icons.pets,
                title: 'No herds registered yet',
                subtitle: 'Tap the + button to register your first herd',
              );
            }

            return BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
              builder: (context, animalTypeState) {
                var animalTypeMap = <String, String>{};
                if (animalTypeState is AnimalTypeLoaded) {
                  for (final at in animalTypeState.animalTypes) {
                    animalTypeMap[at.id] = at.name;
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.herds.length,
                  itemBuilder: (context, index) {
                    final herd = state.herds[index];
                    final animalTypeName =
                        animalTypeMap[herd.animalTypeId] ?? 'Unknown';

                    return EntityListTile(
                      leadingIcon: Icons.pets,
                      leadingBackgroundColor: Colors.orange.shade100,
                      leadingIconColor: Colors.orange.shade700,
                      title: herd.name,
                      subtitleFields: [
                        Text('Type: $animalTypeName'),
                        Text('Location: ${herd.location}'),
                      ],
                      onEdit: () => _showEditHerdDialog(context, herd),
                      onDelete: () => _showDeleteConfirmation(herd),
                    );
                  },
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddHerdDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddHerdDialog(BuildContext context) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    String? selectedAnimalTypeId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) =>
            BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
          builder: (context, animalTypeState) {
            final animalTypes = <AnimalType>[];
            if (animalTypeState is AnimalTypeLoaded) {
              animalTypes.addAll(animalTypeState.animalTypes);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Register New Herd',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Herd Name *',
                                border: OutlineInputBorder(),
                                hintText: 'e.g., Main Chicken Coop',
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (animalTypes.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No animal types available. Please add animal types first.',
                                        style: TextStyle(
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue: selectedAnimalTypeId,
                                decoration: const InputDecoration(
                                  labelText: 'Animal Type *',
                                  border: OutlineInputBorder(),
                                ),
                                items: animalTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type.id,
                                    child: Text(type.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedAnimalTypeId = value;
                                  });
                                },
                              ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: locationController,
                              decoration: const InputDecoration(
                                labelText: 'Location *',
                                border: OutlineInputBorder(),
                                hintText: 'e.g., North Field A',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: animalTypes.isEmpty
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Herd name is required'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                if (selectedAnimalTypeId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Animal type is required'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                if (locationController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Location is required'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                final userId =
                                    await UserUtils.getCurrentUserId();
                                if (userId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('User not authenticated'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                context.read<HerdBloc>().add(
                                  AddHerdEvent(
                                    nameController.text.trim(),
                                    selectedAnimalTypeId!,
                                    locationController.text.trim(),
                                    userId,
                                  ),
                                );
                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Register Herd',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditHerdDialog(BuildContext context, Herd herd) {
    final nameController = TextEditingController(text: herd.name);
    final locationController = TextEditingController(text: herd.location);
    String? selectedAnimalTypeId = herd.animalTypeId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) =>
            BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
          builder: (context, animalTypeState) {
            final animalTypes = <AnimalType>[];
            if (animalTypeState is AnimalTypeLoaded) {
              animalTypes.addAll(animalTypeState.animalTypes);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Herd',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Herd Name *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: selectedAnimalTypeId,
                              decoration: const InputDecoration(
                                labelText: 'Animal Type *',
                                border: OutlineInputBorder(),
                              ),
                              items: animalTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type.id,
                                  child: Text(type.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedAnimalTypeId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: locationController,
                              decoration: const InputDecoration(
                                labelText: 'Location *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Herd name is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (selectedAnimalTypeId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Animal type is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (locationController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Location is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          context.read<HerdBloc>().add(
                            UpdateHerdEvent(
                              herd.id,
                              nameController.text.trim(),
                              selectedAnimalTypeId!,
                              locationController.text.trim(),
                            ),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Update Herd',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Herd herd) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Herd',
      message:
          'Are you sure you want to delete "${herd.name}"? This action cannot be undone.',
    );
    if (confirmed == true) {
      context.read<HerdBloc>().add(DeleteHerdEvent(herd.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${herd.name} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
