import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_list_tile.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';

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
              return const EntityEmptyView(
                icon: Icons.pets,
                title: 'No herds registered yet',
                subtitle: 'Tap the + button to register your first herd',
              );
            }

            return BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
              builder: (context, animalTypeState) {
                final animalTypeMap = <String, String>{};
                if (animalTypeState is AnimalTypeLoaded) {
                  for (final animalType in animalTypeState.animalTypes) {
                    animalTypeMap[animalType.id] = animalType.name;
                  }
                }

                return ListView.builder(
                  padding: context.scrollListPadding(forFab: true),
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildHeadCountChip(
                              'Initial',
                              herd.initialHeadCount,
                              Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            _buildHeadCountChip(
                              'Current',
                              herd.currentHeadCount,
                              Colors.green,
                            ),
                          ],
                        ),
                        Text(
                          'Created: ${_formatDate(herd.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      onEdit: () => _showEditHerdDialog(herd),
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
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: _showAddHerdDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildHeadCountChip(String label, int count, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade700,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddHerdDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final headCountController = TextEditingController();
    String? selectedAnimalTypeId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) =>
            BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
          builder: (context, animalTypeState) {
            final animalTypes = animalTypeState is AnimalTypeLoaded
                ? animalTypeState.animalTypes
                : <AnimalType>[];

            return EntityFormSheet.container(
              context: sheetContext,
              heightFactor: 0.75,
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
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: EntityFormSheet.scrollableForm(
                        context: sheetContext,
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
                              _buildNoAnimalTypesWarning()
                            else
                              DropdownButtonFormField<String>(
                                value: selectedAnimalTypeId,
                                decoration: const InputDecoration(
                                  labelText: 'Animal Type *',
                                  border: OutlineInputBorder(),
                                ),
                                items: animalTypes
                                    .map(
                                      (type) => DropdownMenuItem<String>(
                                        value: type.id,
                                        child: Text(type.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setSheetState(() {
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
                            const SizedBox(height: 16),
                            TextField(
                              controller: headCountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Initial Head Count *',
                                border: OutlineInputBorder(),
                                hintText: 'e.g., 50',
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
                            : () => _submitAddHerd(
                                  sheetContext,
                                  nameController,
                                  locationController,
                                  headCountController,
                                  selectedAnimalTypeId,
                                ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
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

  Future<void> _submitAddHerd(
    BuildContext sheetContext,
    TextEditingController nameController,
    TextEditingController locationController,
    TextEditingController headCountController,
    String? selectedAnimalTypeId,
  ) async {
    if (nameController.text.trim().isEmpty) {
      _showSheetError(sheetContext, 'Herd name is required');
      return;
    }

    if (selectedAnimalTypeId == null) {
      _showSheetError(sheetContext, 'Animal type is required');
      return;
    }

    if (locationController.text.trim().isEmpty) {
      _showSheetError(sheetContext, 'Location is required');
      return;
    }

    final headCount = int.tryParse(headCountController.text.trim());
    if (headCount == null || headCount <= 0) {
      _showSheetError(
        sheetContext,
        'Initial head count must be a positive number',
      );
      return;
    }

    final userId = await UserUtils.getCurrentUserId();
    if (userId == null) {
      _showSheetError(sheetContext, 'User not authenticated');
      return;
    }

    context.read<HerdBloc>().add(
      AddHerdEvent(
        nameController.text.trim(),
        selectedAnimalTypeId,
        locationController.text.trim(),
        userId,
        headCount,
      ),
    );
    Navigator.pop(sheetContext);
  }

  void _showEditHerdDialog(Herd herd) {
    final nameController = TextEditingController(text: herd.name);
    final locationController = TextEditingController(text: herd.location);
    final headCountController = TextEditingController(
      text: herd.initialHeadCount.toString(),
    );
    String? selectedAnimalTypeId = herd.animalTypeId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) =>
            BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
          builder: (context, animalTypeState) {
            final animalTypes = animalTypeState is AnimalTypeLoaded
                ? animalTypeState.animalTypes
                : <AnimalType>[];

            return EntityFormSheet.container(
              context: sheetContext,
              heightFactor: 0.75,
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
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: EntityFormSheet.scrollableForm(
                        context: sheetContext,
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
                              value: selectedAnimalTypeId,
                              decoration: const InputDecoration(
                                labelText: 'Animal Type *',
                                border: OutlineInputBorder(),
                              ),
                              items: animalTypes
                                  .map(
                                    (type) => DropdownMenuItem<String>(
                                      value: type.id,
                                      child: Text(type.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setSheetState(() {
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
                            const SizedBox(height: 16),
                            TextField(
                              controller: headCountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Initial Head Count *',
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
                        onPressed: () => _submitEditHerd(
                          sheetContext,
                          herd,
                          nameController,
                          locationController,
                          headCountController,
                          selectedAnimalTypeId,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(sheetContext).colorScheme.primary,
                          foregroundColor:
                              Theme.of(sheetContext).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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

  void _submitEditHerd(
    BuildContext sheetContext,
    Herd herd,
    TextEditingController nameController,
    TextEditingController locationController,
    TextEditingController headCountController,
    String? selectedAnimalTypeId,
  ) {
    if (nameController.text.trim().isEmpty) {
      _showSheetError(sheetContext, 'Herd name is required');
      return;
    }

    if (selectedAnimalTypeId == null) {
      _showSheetError(sheetContext, 'Animal type is required');
      return;
    }

    if (locationController.text.trim().isEmpty) {
      _showSheetError(sheetContext, 'Location is required');
      return;
    }

    final headCount = int.tryParse(headCountController.text.trim());
    if (headCount == null || headCount <= 0) {
      _showSheetError(
        sheetContext,
        'Initial head count must be a positive number',
      );
      return;
    }

    context.read<HerdBloc>().add(
      UpdateHerdEvent(
        herd.id,
        nameController.text.trim(),
        selectedAnimalTypeId,
        locationController.text.trim(),
        headCount,
      ),
    );
    Navigator.pop(sheetContext);
  }

  Widget _buildNoAnimalTypesWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No animal types available. Please add animal types first.',
              style: TextStyle(color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  void _showSheetError(BuildContext sheetContext, String message) {
    ScaffoldMessenger.of(sheetContext).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Herd herd) async {
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