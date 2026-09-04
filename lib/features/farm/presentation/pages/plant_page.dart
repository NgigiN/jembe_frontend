import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/validation/field_limits.dart';
import 'package:farm_tracker/core/validation/input_formatters.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the standard "Add New Plant" form and resolves once it closes: the
/// new plant's id if the add succeeded, or null if the sheet was dismissed
/// without submitting. Lets other pickers (e.g. Season's plant dropdown)
/// reuse this exact flow instead of duplicating it.
Future<String?> showAddPlantDialog(BuildContext context) async {
  final bloc = context.read<PlantBloc>();
  final beforeIds = bloc.state.plants.map((plant) => plant.id).toSet();
  String? newId;

  final subscription = bloc.stream.listen((state) {
    if (state is PlantLoaded && state.successMessage == 'Crop added') {
      for (final plant in state.plants) {
        if (!beforeIds.contains(plant.id)) {
          newId = plant.id;
          break;
        }
      }
    }
  });

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final varietyController = TextEditingController();

  await EntityFormSheet.show(
    context: context,
    title: 'Add New Plant',
    heightFactor: 0.5,
    submitLabel: 'Add Plant',
    formKey: formKey,
    fields: _PlantPageState._plantFormFields(
      nameController: nameController,
      varietyController: varietyController,
    ),
    onSubmit: (sheetContext) async {
      final userId = await UserUtils.getCurrentUserId();
      if (userId == null) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          AppSnackBar.error(sheetContext, 'User not authenticated'),
        );
        return;
      }

      final plant = PlantModel.create(
        userId: userId,
        name: sanitizeText(nameController.text),
        variety: sanitizeOptionalText(varietyController.text),
      );
      SuccessFeedback.saved();
      bloc.add(AddPlantEvent(plant));
      Navigator.pop(sheetContext);
    },
  );

  await subscription.cancel();
  return newId;
}

class PlantPage extends StatefulWidget {
  const PlantPage({super.key});

  @override
  State<PlantPage> createState() => _PlantPageState();
}

class _PlantPageState extends State<PlantPage> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<PlantBloc>();
    if (bloc.state is! PlantLoaded) {
      bloc.add(GetPlantsEvent());
    }
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
      body: RefreshIndicator(
        onRefresh: () async {
          final bloc = context.read<PlantBloc>()..add(GetPlantsEvent());
          await bloc.stream.firstWhere(
            (s) => s is PlantLoaded || s is PlantError,
          );
        },
        child: BlocConsumer<PlantBloc, PlantState>(
        listener: (context, state) {
          if (state is PlantLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(context, state.successMessage!),
            );
          } else if (state is PlantError && state.plants.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(context, state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is PlantLoading && state.plants.isEmpty) {
            return _scrollableEmptyState(
              const Center(child: CircularProgressIndicator()),
            );
          }

          if (state is PlantError && state.plants.isEmpty) {
            return _scrollableEmptyState(
              EntityErrorView(
                message: state.message,
                onRetry: () => context.read<PlantBloc>().add(GetPlantsEvent()),
              ),
            );
          }

          final plants = state.plants;
          if (plants.isEmpty) {
            return _scrollableEmptyState(
              const EntityEmptyView(
                icon: Icons.eco,
                title: 'No plants registered yet',
                subtitle: 'Tap the + button to add your first plant',
              ),
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.scrollListPadding(forFab: true),
            itemCount: plants.length,
            itemBuilder: (context, index) {
              final plant = plants[index];
                return EntityCard(
                  icon: Icons.eco,
                  iconColor: AppColors.plantCategory,
                  title: plant.name,
                  subtitle: plant.variety?.isNotEmpty ?? false
                      ? plant.variety!
                      : 'Added ${_formatDate(plant.createdAt)}',
                  onTap: () => _showPlantDetails(plant),
                );
              },
            );
        },
        ),
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: _showAddPlantDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// Makes a non-scrollable empty/error/loading state (a centered
  /// icon+text column or spinner) pullable: [RefreshIndicator] needs a
  /// scrollable descendant to detect the pull gesture, even when there's
  /// nothing to scroll.
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
          plant.variety?.isNotEmpty ?? false ? plant.variety! : '—',
        ),
        EntityDetailRow('Created', _formatDate(plant.createdAt)),
      ],
      onEdit: () => _showEditPlantDialog(plant),
      onDelete: () => _showDeleteConfirmation(plant),
    );
  }

  void _showAddPlantDialog() {
    showAddPlantDialog(context);
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
        SuccessFeedback.saved();
        context.read<PlantBloc>().add(UpdatePlantEvent(updatedPlant));
        Navigator.pop(sheetContext);
      },
    );
  }

  static List<Widget> _plantFormFields({
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
        ),
        validator: optionalVariety,
        inputFormatters: nameFormatters(maxLength: FieldLimits.varietyMax),
        maxLength: FieldLimits.varietyMax,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
            null,
      ),
    ];
  }

  Future<void> _showDeleteConfirmation(Plant plant) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Plant',
      message:
          'Are you sure you want to delete "${plant.name}"${plant.variety != null ? ' (${plant.variety})' : ''}? This action cannot be undone.',
    );
    if (confirmed ?? false) {
      SuccessFeedback.deleted();
      context.read<PlantBloc>().add(DeletePlantEvent(plant.id));
    }
  }
}
