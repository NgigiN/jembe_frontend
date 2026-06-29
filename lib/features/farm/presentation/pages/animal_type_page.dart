import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';

class AnimalTypePage extends StatefulWidget {
  const AnimalTypePage({super.key});

  @override
  State<AnimalTypePage> createState() => _AnimalTypePageState();
}

class _AnimalTypePageState extends State<AnimalTypePage> {
  @override
  void initState() {
    super.initState();
    context.read<AnimalTypeBloc>().add(GetAnimalTypesEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal Types'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
        builder: (context, state) {
          if (state is AnimalTypeLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AnimalTypeError) {
            return EntityErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<AnimalTypeBloc>().add(GetAnimalTypesEvent()),
            );
          }

          if (state is AnimalTypeLoaded) {
            if (state.animalTypes.isEmpty) {
              return EntityEmptyView(
                icon: Icons.category,
                title: 'No animal types added yet',
                subtitle: 'Tap the + button to add your first animal type',
              );
            }

            return ListView.builder(
              padding: context.scrollListPadding(forFab: true),
              itemCount: state.animalTypes.length,
              itemBuilder: (context, index) {
                final animalType = state.animalTypes[index];
                return EntityCard(
                  icon: Icons.category,
                  iconColor: AppColors.animalCategory,
                  title: animalType.name,
                  subtitle: animalType.notes?.isNotEmpty == true
                      ? animalType.notes!
                      : 'Added ${_formatDate(animalType.createdAt)}',
                  onTap: () => _showAnimalTypeDetails(animalType),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => _showAddAnimalTypeDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAnimalTypeDetails(AnimalType animalType) {
    EntityDetailsSheet.show(
      context: context,
      title: animalType.name,
      details: [
        EntityDetailRow(
          'Notes',
          animalType.notes?.isNotEmpty == true ? animalType.notes! : '—',
        ),
        EntityDetailRow('Created', _formatDate(animalType.createdAt)),
      ],
      onEdit: () => _showEditAnimalTypeDialog(animalType),
      onDelete: () => _showDeleteConfirmation(animalType),
    );
  }

  void _showAddAnimalTypeDialog() {
    final nameController = TextEditingController();
    final notesController = TextEditingController();

    EntityFormSheet.show(
      context: context,
      title: 'Add Animal Type',
      heightFactor: 0.6,
      submitLabel: 'Add Animal Type',
      fields: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Animal Type Name *',
            border: OutlineInputBorder(),
            hintText: 'e.g., Chickens, Cows, Goats',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes (Optional)',
            border: OutlineInputBorder(),
            hintText: 'e.g., Poultry for eggs and meat',
          ),
        ),
      ],
      onSubmit: (sheetContext) async {
        if (nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(
              content: Text('Animal type name is required'),
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

        final notes = notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim();

        context.read<AnimalTypeBloc>().add(
          AddAnimalTypeEvent(
            nameController.text.trim(),
            notes,
            userId,
          ),
        );
        Navigator.pop(sheetContext);
      },
    );
  }

  void _showEditAnimalTypeDialog(AnimalType animalType) {
    final nameController = TextEditingController(text: animalType.name);
    final notesController = TextEditingController(text: animalType.notes ?? '');

    EntityFormSheet.show(
      context: context,
      title: 'Edit Animal Type',
      heightFactor: 0.6,
      submitLabel: 'Update Animal Type',
      fields: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Animal Type Name *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes (Optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
      onSubmit: (sheetContext) {
        if (nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(
              content: Text('Animal type name is required'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final notes = notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim();

        context.read<AnimalTypeBloc>().add(
          UpdateAnimalTypeEvent(
            animalType.id,
            nameController.text.trim(),
            notes,
          ),
        );
        Navigator.pop(sheetContext);
      },
    );
  }

  void _showDeleteConfirmation(AnimalType animalType) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Animal Type',
      message:
          'Are you sure you want to delete "${animalType.name}"? This action cannot be undone.',
    );
    if (confirmed == true) {
      context.read<AnimalTypeBloc>().add(
        DeleteAnimalTypeEvent(animalType.id),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${animalType.name} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
