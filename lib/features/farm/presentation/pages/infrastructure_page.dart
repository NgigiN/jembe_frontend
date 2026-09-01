import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/core/validation/parse.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_state.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';

class InfrastructurePage extends StatefulWidget {
  const InfrastructurePage({super.key});

  @override
  State<InfrastructurePage> createState() => _InfrastructurePageState();
}

class _InfrastructurePageState extends State<InfrastructurePage> {
  static const _infrastructureTypes = [
    'Store',
    'House',
    'Fence',
    'Barn',
    'Greenhouse',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    context.read<InfrastructureBloc>().add(GetInfrastructuresEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infrastructure'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<InfrastructureBloc, InfrastructureState>(
        listener: (context, state) {
          if (state is InfrastructureLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(context, state.successMessage!),
            );
          } else if (state is InfrastructureError && state.infrastructures.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(context, state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is InfrastructureLoading && state.infrastructures.isEmpty) {
            return const SkeletonEntityList(icon: Icons.home_work);
          }

          if (state is InfrastructureError && state.infrastructures.isEmpty) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context
                  .read<InfrastructureBloc>()
                  .add(GetInfrastructuresEvent()),
            );
          }

          final infrastructures = state.infrastructures;
          if (infrastructures.isEmpty) {
            return const EntityEmptyView(
              icon: Icons.foundation,
              title: 'No infrastructure registered yet',
              subtitle: 'Tap the + button to add your first infrastructure item',
            );
          }

          return ListView.builder(
            padding: context.scrollListPadding(forFab: true),
            itemCount: infrastructures.length,
            itemBuilder: (context, index) {
              final item = infrastructures[index];
              final location = item.location.isNotEmpty
                  ? item.location
                  : 'No location';
              return EntityCard(
                icon: _iconForType(item.type),
                iconColor: AppColors.animalCategory,
                title: item.name,
                subtitle: '${item.type} · $location',
                trailing: Text(
                  'KES ${item.cost.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                onTap: () => _showInfrastructureDetails(item),
              );
            },
          );
        },
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => _showAddOrEditDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'store':
        return Icons.store;
      case 'house':
        return Icons.home;
      case 'fence':
        return Icons.fence;
      case 'barn':
        return Icons.roofing;
      case 'greenhouse':
        return Icons.opacity;
      default:
        return Icons.foundation;
    }
  }

  void _showInfrastructureDetails(Infrastructure item) {
    EntityDetailsSheet.show(
      context: context,
      title: item.name,
      details: [
        EntityDetailRow('Type', item.type),
        EntityDetailRow(
          'Location',
          item.location.isNotEmpty ? item.location : '—',
        ),
        EntityDetailRow(
          'Cost',
          'KES ${item.cost.toStringAsFixed(2)}',
          isPrimary: true,
        ),
        EntityDetailRow('Date', _formatDate(item.date)),
        if (item.notes.isNotEmpty) EntityDetailRow('Notes', item.notes),
      ],
      onEdit: () => _showAddOrEditDialog(item: item),
      onDelete: () => _showDeleteConfirmation(item),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddOrEditDialog({Infrastructure? item}) {
    final formKey = GlobalKey<FormState>();
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final locationController = TextEditingController(text: item?.location ?? '');
    final costController = TextEditingController(
      text: item?.cost.toString() ?? '',
    );
    final notesController = TextEditingController(text: item?.notes ?? '');
    var selectedType = item != null && _infrastructureTypes.contains(item.type)
        ? item.type
        : _infrastructureTypes.first;
    var selectedDate = item?.date ?? DateTime.now();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntityFormSheet.container(
          context: sheetContext,
          heightFactor: 0.82,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing
                          ? 'Edit Infrastructure'
                          : 'Add Infrastructure',
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
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Infrastructure Type *',
                            ),
                            items: _infrastructureTypes
                                .map(
                                  (type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setSheetState(() => selectedType = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          ValidatedNameField(
                            controller: nameController,
                            labelText: 'Infrastructure Name *',
                            hintText: 'e.g., Main Barn, North Fence',
                            validator: (value) =>
                                requiredName(value, fieldLabel: 'Name'),
                          ),
                          const SizedBox(height: 16),
                          ValidatedLocationField(
                            controller: locationController,
                            labelText: 'Location *',
                            hintText: 'e.g., North Field',
                            validator: (value) => requiredLocation(value),
                          ),
                          const SizedBox(height: 16),
                          ValidatedDecimalField(
                            controller: costController,
                            labelText: 'Cost (KES) *',
                            hintText: 'e.g., 5000.00',
                            validator: (value) =>
                                nonNegativeDecimal(value, fieldLabel: 'Cost'),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: sheetContext,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setSheetState(() => selectedDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ValidatedNotesField(
                            controller: notesController,
                            labelText: 'Notes',
                            validator: optionalNotes,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      _submitInfrastructure(
                        sheetContext,
                        isEditing: isEditing,
                        item: item,
                        selectedType: selectedType,
                        selectedDate: selectedDate,
                        nameController: nameController,
                        locationController: locationController,
                        costController: costController,
                        notesController: notesController,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isEditing ? 'Update Infrastructure' : 'Add Infrastructure',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitInfrastructure(
    BuildContext sheetContext, {
    required bool isEditing,
    Infrastructure? item,
    required String selectedType,
    required DateTime selectedDate,
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController costController,
    required TextEditingController notesController,
  }) async {
    final cost = parseNonNegativeDecimal(costController.text);
    final notes = sanitizeOptionalText(notesController.text);

    if (isEditing && item != null) {
      SuccessFeedback.saved();
      context.read<InfrastructureBloc>().add(
        UpdateInfrastructureEvent(
          id: item.id,
          type: selectedType,
          name: sanitizeText(nameController.text),
          location: sanitizeText(locationController.text),
          cost: cost,
          date: selectedDate,
          notes: notes,
        ),
      );
      Navigator.pop(sheetContext);
      return;
    }

    final userId = await UserUtils.getCurrentUserId();
    if (userId == null) {
      _showSheetError(sheetContext, 'User not authenticated');
      return;
    }

    SuccessFeedback.saved();
    context.read<InfrastructureBloc>().add(
      AddInfrastructureEvent(
        type: selectedType,
        name: sanitizeText(nameController.text),
        location: sanitizeText(locationController.text),
        cost: cost,
        date: selectedDate,
        userId: userId,
        notes: notes,
      ),
    );
    Navigator.pop(sheetContext);
  }

  void _showSheetError(BuildContext sheetContext, String message) {
    ScaffoldMessenger.of(sheetContext).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Infrastructure item) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Infrastructure',
      message:
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
    );
    if (confirmed == true) {
      SuccessFeedback.deleted();
      context.read<InfrastructureBloc>().add(
        DeleteInfrastructureEvent(item.id),
      );
    }
  }
}