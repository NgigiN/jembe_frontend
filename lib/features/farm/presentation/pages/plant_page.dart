import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/validation/field_limits.dart';
import 'package:farm_tracker/core/validation/input_formatters.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
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
              padding: context.scrollListPadding(forFab: true),
              itemCount: state.plants.length,
              itemBuilder: (context, index) {
                final plant = state.plants[index];
                return EntityCard(
                  icon: Icons.eco,
                  iconColor: AppColors.plantCategory,
                  title: plant.name,
                  subtitle: plant.variety?.isNotEmpty == true
                      ? plant.variety!
                      : 'Added ${_formatDate(plant.createdAt)}',
                  onTap: () => _showPlantDetails(plant),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => _showAddPlantDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showPlantDetails(Plant plant) {
    EntityDetailsSheet.show(
      context: context,
      title: plant.name,
      details: [
        EntityDetailRow(
          'Variety',
          plant.variety?.isNotEmpty == true ? plant.variety! : '—',
        ),
        EntityDetailRow('Created', _formatDate(plant.createdAt)),
      ],
      onEdit: () => _showEditPlantDialog(plant),
      onDelete: () => _showDeleteConfirmation(plant),
    );
  }

  void _showAddPlantDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final varietyController = TextEditingController();

    EntityFormSheet.show(
      context: context,
      title: 'Add New Plant',
      heightFactor: 0.5,
      submitLabel: 'Add Plant',
      formKey: formKey,
      fields: _plantFormFields(
        nameController: nameController,
        varietyController: varietyController,
      ),
      onSubmit: (sheetContext) async {
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
          name: sanitizeText(nameController.text),
          variety: sanitizeOptionalText(varietyController.text),
        );
        context.read<PlantBloc>().add(AddPlantEvent(plant));
        Navigator.pop(sheetContext);
      },
    );
  }

  void _showEditPlantDialog(Plant plant) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: plant.name);
    final varietyController = TextEditingController(text: plant.variety ?? '');

    EntityFormSheet.show(
      context: context,
      title: 'Edit Plant',
      heightFactor: 0.5,
      submitLabel: 'Update Plant',
      formKey: formKey,
      fields: _plantFormFields(
        nameController: nameController,
        varietyController: varietyController,
      ),
      onSubmit: (sheetContext) async {
        final updatedPlant = PlantModel(
          id: plant.id,
          userId: plant.userId,
          name: sanitizeText(nameController.text),
          variety: sanitizeOptionalText(varietyController.text),
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

  List<Widget> _plantFormFields({
    required TextEditingController nameController,
    required TextEditingController varietyController,
  }) {
    return [
      ValidatedNameField(
        controller: nameController,
        labelText: 'Plant Name *',
        validator: (value) => requiredName(value, fieldLabel: 'Plant name'),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: varietyController,
        decoration: const InputDecoration(
          labelText: 'Variety (Optional)',
          border: OutlineInputBorder(),
        ),
        validator: optionalVariety,
        inputFormatters: nameFormatters(maxLength: FieldLimits.varietyMax),
        maxLength: FieldLimits.varietyMax,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
            null,
      ),
    ];
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
