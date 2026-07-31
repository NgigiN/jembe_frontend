import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';

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
      body: BlocConsumer<HerdBloc, HerdState>(
        listener: (context, state) {
          if (state is HerdLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(state.successMessage!),
            );
          } else if (state is HerdError && state.herds.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is HerdLoading && state.herds.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HerdError && state.herds.isEmpty) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<HerdBloc>().add(GetHerdsEvent()),
            );
          }

          final herds = state.herds;
          if (herds.isEmpty) {
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
                  itemCount: herds.length,
                  itemBuilder: (context, index) {
                    final herd = herds[index];
                    final animalTypeName =
                        animalTypeMap[herd.animalTypeId] ?? 'Unknown';

                    return EntityCard(
                      icon: Icons.pets,
                      iconColor: AppColors.animalCategory,
                      title: herd.name,
                      subtitle:
                          '$animalTypeName · ${herd.location}',
                      trailing: Text(
                        '${herd.currentHeadCount} head',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      onTap: () => _showHerdDetails(
                        herd,
                        animalTypeName: animalTypeName,
                      ),
                    );
                  },
                );
              },
            );
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showHerdDetails(Herd herd, {required String animalTypeName}) {
    EntityDetailsSheet.show(
      context: context,
      title: herd.name,
      details: [
        EntityDetailRow('Animal Type', animalTypeName),
        EntityDetailRow('Location', herd.location),
        EntityDetailRow('Initial Headcount', herd.initialHeadCount.toString()),
        EntityDetailRow(
          'Current Headcount',
          herd.currentHeadCount.toString(),
          isPrimary: true,
        ),
        EntityDetailRow('Created', _formatDate(herd.createdAt)),
      ],
      onEdit: () => _showEditHerdDialog(herd),
      onDelete: () => _showDeleteConfirmation(herd),
    );
  }

  void _showAddHerdDialog() {
    final formKey = GlobalKey<FormState>();
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
                        child: Form(
                          key: formKey,
                          child: Column(
                            children: _herdFormFields(
                              nameController: nameController,
                              locationController: locationController,
                              headCountController: headCountController,
                              animalTypes: animalTypes,
                              selectedAnimalTypeId: selectedAnimalTypeId,
                              onAnimalTypeChanged: (value) {
                                setSheetState(() {
                                  selectedAnimalTypeId = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: animalTypes.isEmpty
                            ? null
                            : () {
                                if (!(formKey.currentState?.validate() ?? false)) {
                                  return;
                                }
                                _submitAddHerd(
                                  sheetContext,
                                  nameController,
                                  locationController,
                                  headCountController,
                                  selectedAnimalTypeId,
                                );
                              },
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
    final headCount = parsePositiveInt(headCountController.text);
    if (headCount == null) return;

    final userId = await UserUtils.getCurrentUserId();
    if (userId == null) {
      _showSheetError(sheetContext, 'User not authenticated');
      return;
    }

    context.read<HerdBloc>().add(
      AddHerdEvent(
        sanitizeText(nameController.text),
        selectedAnimalTypeId!,
        sanitizeText(locationController.text),
        userId,
        headCount,
      ),
    );
    Navigator.pop(sheetContext);
  }

  void _showEditHerdDialog(Herd herd) {
    final formKey = GlobalKey<FormState>();
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
                        child: Form(
                          key: formKey,
                          child: Column(
                            children: _herdFormFields(
                              nameController: nameController,
                              locationController: locationController,
                              headCountController: headCountController,
                              animalTypes: animalTypes,
                              selectedAnimalTypeId: selectedAnimalTypeId,
                              onAnimalTypeChanged: (value) {
                                setSheetState(() {
                                  selectedAnimalTypeId = value;
                                });
                              },
                            ),
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
                          _submitEditHerd(
                            sheetContext,
                            herd,
                            nameController,
                            locationController,
                            headCountController,
                            selectedAnimalTypeId,
                          );
                        },
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
    final headCount = parsePositiveInt(headCountController.text);
    if (headCount == null) return;

    context.read<HerdBloc>().add(
      UpdateHerdEvent(
        herd.id,
        sanitizeText(nameController.text),
        selectedAnimalTypeId!,
        sanitizeText(locationController.text),
        headCount,
      ),
    );
    Navigator.pop(sheetContext);
  }

  List<Widget> _herdFormFields({
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController headCountController,
    required List<AnimalType> animalTypes,
    required String? selectedAnimalTypeId,
    required ValueChanged<String?> onAnimalTypeChanged,
  }) {
    return [
      ValidatedNameField(
        controller: nameController,
        labelText: 'Herd Name *',
        hintText: 'e.g., Main Chicken Coop',
        validator: (value) => requiredName(value, fieldLabel: 'Herd name'),
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
          onChanged: onAnimalTypeChanged,
          validator: (value) =>
              requiredSelection(value, fieldLabel: 'animal type'),
        ),
      const SizedBox(height: 16),
      ValidatedLocationField(
        controller: locationController,
        labelText: 'Location *',
        hintText: 'e.g., North Field A',
        validator: (value) => requiredLocation(value),
      ),
      const SizedBox(height: 16),
      ValidatedIntegerField(
        controller: headCountController,
        labelText: 'Initial Head Count *',
        hintText: 'e.g., 50',
        validator: (value) => positiveInt(value, fieldLabel: 'Head count'),
      ),
    ];
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
    }
  }
}