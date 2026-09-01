import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/feedback/success_feedback.dart';
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
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';

/// Opens the standard "Add Animal Type" form and resolves once it closes:
/// the new animal type's id if the add succeeded, or null if the sheet was
/// dismissed without submitting. Lets other pickers (e.g. Herd's animal-type
/// dropdown) reuse this exact flow instead of duplicating it.
Future<String?> showAddAnimalTypeDialog(BuildContext context) async {
  final bloc = context.read<AnimalTypeBloc>();
  final beforeIds = bloc.state.animalTypes.map((type) => type.id).toSet();
  String? newId;

  final subscription = bloc.stream.listen((state) {
    if (state is AnimalTypeLoaded && state.successMessage == 'Animal type added') {
      for (final type in state.animalTypes) {
        if (!beforeIds.contains(type.id)) {
          newId = type.id;
          break;
        }
      }
    }
  });

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final notesController = TextEditingController();

  await EntityFormSheet.show(
    context: context,
    title: 'Add Animal Type',
    heightFactor: 0.6,
    submitLabel: 'Add Animal Type',
    formKey: formKey,
    fields: _AnimalTypePageState._animalTypeFormFields(
      nameController: nameController,
      notesController: notesController,
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

      SuccessFeedback.saved();
      bloc.add(
        AddAnimalTypeEvent(
          sanitizeText(nameController.text),
          sanitizeOptionalText(notesController.text),
          userId,
        ),
      );
      Navigator.pop(sheetContext);
    },
  );

  await subscription.cancel();
  return newId;
}

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
      body: BlocConsumer<AnimalTypeBloc, AnimalTypeState>(
        listener: (context, state) {
          if (state is AnimalTypeLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(state.successMessage!),
            );
          } else if (state is AnimalTypeError && state.animalTypes.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is AnimalTypeLoading && state.animalTypes.isEmpty) {
            return const SkeletonEntityList(icon: Icons.pets);
          }

          if (state is AnimalTypeError && state.animalTypes.isEmpty) {
            return EntityErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<AnimalTypeBloc>().add(GetAnimalTypesEvent()),
            );
          }

          final animalTypes = state.animalTypes;
          if (animalTypes.isEmpty) {
            return EntityEmptyView(
              icon: Icons.category,
              title: 'No animal types added yet',
              subtitle: 'Tap the + button to add your first animal type',
            );
          }

          return ListView.builder(
            padding: context.scrollListPadding(forFab: true),
            itemCount: animalTypes.length,
            itemBuilder: (context, index) {
              final animalType = animalTypes[index];
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
    showAddAnimalTypeDialog(context);
  }

  void _showEditAnimalTypeDialog(AnimalType animalType) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: animalType.name);
    final notesController = TextEditingController(text: animalType.notes ?? '');

    EntityFormSheet.show(
      context: context,
      title: 'Edit Animal Type',
      heightFactor: 0.6,
      submitLabel: 'Update Animal Type',
      formKey: formKey,
      fields: _animalTypeFormFields(
        nameController: nameController,
        notesController: notesController,
      ),
      onSubmit: (sheetContext) {
        SuccessFeedback.saved();
        context.read<AnimalTypeBloc>().add(
          UpdateAnimalTypeEvent(
            animalType.id,
            sanitizeText(nameController.text),
            sanitizeOptionalText(notesController.text),
          ),
        );
        Navigator.pop(sheetContext);
      },
    );
  }

  static List<Widget> _animalTypeFormFields({
    required TextEditingController nameController,
    required TextEditingController notesController,
  }) {
    return [
      ValidatedNameField(
        controller: nameController,
        labelText: 'Animal Type Name *',
        hintText: 'e.g., Chickens, Cows, Goats',
        validator: (value) =>
            requiredName(value, fieldLabel: 'Animal type name'),
      ),
      const SizedBox(height: 16),
      ValidatedNotesField(
        controller: notesController,
        labelText: 'Notes (Optional)',
        validator: optionalNotes,
      ),
    ];
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
    }
  }
}
