import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_list_tile.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';

class PlantPage extends StatefulWidget {
  const PlantPage({super.key});

  @override
  State<PlantPage> createState() => _PlantPageState();
}

class _PlantPageState extends State<PlantPage> {
  @override
  void initState() {
    super.initState();
    context.read<PlantBloc>().add(GetPlantsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Management'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<PlantBloc, PlantState>(
        builder: (context, state) {
          if (state is PlantLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PlantError) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<PlantBloc>().add(GetPlantsEvent()),
            );
          }

          if (state is PlantLoaded) {
            if (state.plants.isEmpty) {
              return EntityEmptyView(
                icon: Icons.eco,
                title: 'No plants registered yet',
                subtitle: 'Tap the + button to add your first plant',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.plants.length,
              itemBuilder: (context, index) {
                final plant = state.plants[index];
                return EntityListTile(
                  leadingIcon: Icons.eco,
                  leadingBackgroundColor: Colors.green.shade100,
                  leadingIconColor: Colors.green.shade700,
                  title: plant.name,
                  subtitleFields: [
                    if (plant.variety != null && plant.variety!.isNotEmpty)
                      Text('Variety: ${plant.variety}'),
                    Text(
                      'Created: ${_formatDate(plant.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  onEdit: () => _showEditPlantDialog(plant),
                  onDelete: () => _showDeleteConfirmation(plant),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPlantDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddPlantDialog() {
    final nameController = TextEditingController();
    final varietyController = TextEditingController();

    EntityFormSheet.show(
      context: context,
      title: 'Add New Plant',
      heightFactor: 0.5,
      submitLabel: 'Add Plant',
      fields: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Plant Name *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: varietyController,
          decoration: const InputDecoration(
            labelText: 'Variety (Optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
      onSubmit: (sheetContext) async {
        if (nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(
              content: Text('Plant name is required'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final userId = await UserUtils.getCurrentUserId();
        if (userId == null) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(
              content: Text('User not authenticated'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final plant = PlantModel.create(
          userId: userId ?? '',
          name: nameController.text.trim(),
          variety: varietyController.text.trim().isEmpty
              ? null
              : varietyController.text.trim(),
        );
        context.read<PlantBloc>().add(AddPlantEvent(plant));
        Navigator.pop(sheetContext);
      },
    );
  }

  void _showEditPlantDialog(Plant plant) {
    final nameController = TextEditingController(text: plant.name);
    final varietyController = TextEditingController(text: plant.variety ?? '');

    EntityFormSheet.show(
      context: context,
      title: 'Edit Plant',
      heightFactor: 0.5,
      submitLabel: 'Update Plant',
      fields: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Plant Name *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: varietyController,
          decoration: const InputDecoration(
            labelText: 'Variety (Optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
      onSubmit: (sheetContext) async {
        if (nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(
              content: Text('Plant name is required'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final updatedPlant = PlantModel(
          id: plant.id,
          userId: plant.userId,
          name: nameController.text.trim(),
          variety: varietyController.text.trim().isEmpty
              ? null
              : varietyController.text.trim(),
          createdAt: plant.createdAt,
          updatedAt: DateTime.now(),
        );
        context.read<PlantBloc>().add(UpdatePlantEvent(updatedPlant));
        Navigator.pop(sheetContext);
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(
            content: Text('Plant updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Plant plant) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Plant',
      message:
          'Are you sure you want to delete "${plant.name}"${plant.variety != null ? ' (${plant.variety})' : ''}? This action cannot be undone.',
    );
    if (confirmed == true) {
      context.read<PlantBloc>().add(DeletePlantEvent(plant.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${plant.name} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
