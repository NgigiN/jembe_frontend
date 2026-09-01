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
import 'package:farm_tracker/core/widgets/crud/entity_picker_with_add.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_type_page.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';

/// Validates and submits the "Register New Herd" form. A top-level function
/// (not inlined in the button's onPressed) because `selectedStartDate` is a
/// captured, mutable closure variable — Dart won't promote its nullability
/// after a null check inline, but it will for a plain parameter here.
Future<void> _submitAddHerd({
  required HerdBloc herdBloc,
  required BuildContext sheetContext,
  required TextEditingController nameController,
  required TextEditingController locationController,
  required TextEditingController headCountController,
  required String? selectedAnimalTypeId,
  required DateTime? selectedStartDate,
  required DateTime? selectedEndDate,
}) async {
  final headCount = parsePositiveInt(headCountController.text);
  if (headCount == null) return;
  if (selectedStartDate == null) return;

  final userId = await UserUtils.getCurrentUserId();
  if (userId == null) {
    _HerdPageState._showSheetError(sheetContext, 'User not authenticated');
    return;
  }

  SuccessFeedback.saved();
  herdBloc.add(
    AddHerdEvent(
      sanitizeText(nameController.text),
      selectedAnimalTypeId!,
      sanitizeText(locationController.text),
      userId,
      headCount,
      startDate: selectedStartDate,
      endDate: selectedEndDate,
    ),
  );
  Navigator.pop(sheetContext);
}

/// Opens the standard "Register New Herd" form and resolves once it closes:
/// the new herd's id if the add succeeded, or null if the sheet was
/// dismissed without submitting. Lets other pickers reuse this exact flow
/// instead of duplicating it.
Future<String?> showAddHerdDialog(BuildContext context) async {
  final herdBloc = context.read<HerdBloc>();
  final beforeIds = herdBloc.state.herds.map((herd) => herd.id).toSet();
  String? newId;

  final subscription = herdBloc.stream.listen((state) {
    if (state is HerdLoaded && state.successMessage == 'Herd created') {
      for (final herd in state.herds) {
        if (!beforeIds.contains(herd.id)) {
          newId = herd.id;
          break;
        }
      }
    }
  });

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final headCountController = TextEditingController();
  String? selectedAnimalTypeId;
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) =>
          BlocBuilder<AnimalTypeBloc, AnimalTypeState>(
        bloc: context.read<AnimalTypeBloc>(),
        builder: (builderContext, animalTypeState) {
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
                          children: _HerdPageState._herdFormFields(
                            context: builderContext,
                            nameController: nameController,
                            locationController: locationController,
                            headCountController: headCountController,
                            animalTypes: animalTypes,
                            selectedAnimalTypeId: selectedAnimalTypeId,
                            selectedStartDate: selectedStartDate,
                            selectedEndDate: selectedEndDate,
                            onAnimalTypeChanged: (value) {
                              setSheetState(() {
                                selectedAnimalTypeId = value;
                              });
                            },
                            onStartDateChanged: (value) {
                              setSheetState(() {
                                selectedStartDate = value;
                              });
                            },
                            onEndDateChanged: (value) {
                              setSheetState(() {
                                selectedEndDate = value;
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
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              _submitAddHerd(
                                herdBloc: herdBloc,
                                sheetContext: sheetContext,
                                nameController: nameController,
                                locationController: locationController,
                                headCountController: headCountController,
                                selectedAnimalTypeId: selectedAnimalTypeId,
                                selectedStartDate: selectedStartDate,
                                selectedEndDate: selectedEndDate,
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

  await subscription.cancel();
  return newId;
}

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
              AppSnackBar.success(context, state.successMessage!),
            );
          } else if (state is HerdError && state.herds.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(context, state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is HerdLoading && state.herds.isEmpty) {
            return const SkeletonEntityList(icon: Icons.pets);
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

  static String _formatDate(DateTime date) {
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
    showAddHerdDialog(context);
  }

  void _showEditHerdDialog(Herd herd) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: herd.name);
    final locationController = TextEditingController(text: herd.location);
    final headCountController = TextEditingController(
      text: herd.initialHeadCount.toString(),
    );
    String? selectedAnimalTypeId = herd.animalTypeId;
    DateTime? selectedStartDate = herd.startDate;
    DateTime? selectedEndDate = herd.endDate;

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
                              context: context,
                              nameController: nameController,
                              locationController: locationController,
                              headCountController: headCountController,
                              animalTypes: animalTypes,
                              selectedAnimalTypeId: selectedAnimalTypeId,
                              selectedStartDate: selectedStartDate,
                              selectedEndDate: selectedEndDate,
                              onAnimalTypeChanged: (value) {
                                setSheetState(() {
                                  selectedAnimalTypeId = value;
                                });
                              },
                              onStartDateChanged: (value) {
                                setSheetState(() {
                                  selectedStartDate = value;
                                });
                              },
                              onEndDateChanged: (value) {
                                setSheetState(() {
                                  selectedEndDate = value;
                                });
                              },
                              showClearEndDate: true,
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
                            selectedStartDate,
                            selectedEndDate,
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
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
  ) {
    final headCount = parsePositiveInt(headCountController.text);
    if (headCount == null) return;
    if (selectedStartDate == null) return;

    SuccessFeedback.saved();
    context.read<HerdBloc>().add(
      UpdateHerdEvent(
        herd.id,
        sanitizeText(nameController.text),
        selectedAnimalTypeId!,
        sanitizeText(locationController.text),
        headCount,
        startDate: selectedStartDate,
        endDate: selectedEndDate,
      ),
    );
    Navigator.pop(sheetContext);
  }

  static List<Widget> _herdFormFields({
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController locationController,
    required TextEditingController headCountController,
    required List<AnimalType> animalTypes,
    required String? selectedAnimalTypeId,
    required DateTime? selectedStartDate,
    required DateTime? selectedEndDate,
    required ValueChanged<String?> onAnimalTypeChanged,
    required ValueChanged<DateTime?> onStartDateChanged,
    required ValueChanged<DateTime?> onEndDateChanged,
    bool showClearEndDate = false,
  }) {
    return [
      ValidatedNameField(
        controller: nameController,
        labelText: 'Herd Name *',
        hintText: 'e.g., Main Chicken Coop',
        validator: (value) => requiredName(value, fieldLabel: 'Herd name'),
      ),
      const SizedBox(height: 16),
      EntityPickerWithAdd<AnimalType>(
        items: animalTypes,
        selectedId: selectedAnimalTypeId,
        idOf: (type) => type.id,
        labelOf: (type) => type.name,
        labelText: 'Animal Type *',
        validator: (value) =>
            requiredSelection(value, fieldLabel: 'animal type'),
        onChanged: onAnimalTypeChanged,
        onAddNew: showAddAnimalTypeDialog,
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
      const SizedBox(height: 16),
      FormField<DateTime?>(
        initialValue: selectedStartDate,
        validator: (value) =>
            value == null ? 'Start date is required' : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date *'),
              subtitle: Text(
                selectedStartDate != null
                    ? _formatDate(selectedStartDate)
                    : 'Select start date',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedStartDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  onStartDateChanged(date);
                  field.didChange(date);
                }
              },
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FormField<DateTime?>(
        initialValue: selectedEndDate,
        validator: (value) => validateEndDateAfterStart(
          start: selectedStartDate,
          end: value,
        ),
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End Date (Optional)'),
              subtitle: Text(
                selectedEndDate != null
                    ? _formatDate(selectedEndDate)
                    : 'Select end date (optional) — leave empty for an ongoing herd',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showClearEndDate && selectedEndDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        onEndDateChanged(null);
                        field.didChange(null);
                      },
                    ),
                  const Icon(Icons.calendar_today),
                ],
              ),
              onTap: () async {
                final initialDate =
                    selectedEndDate ?? selectedStartDate ?? DateTime.now();
                final firstDate = selectedStartDate ?? DateTime(2020);
                final pickerInitialDate = initialDate.isBefore(firstDate)
                    ? firstDate
                    : initialDate;

                final date = await showDatePicker(
                  context: context,
                  initialDate: pickerInitialDate,
                  firstDate: firstDate,
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  onEndDateChanged(date);
                  field.didChange(date);
                }
              },
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  static void _showSheetError(BuildContext sheetContext, String message) {
    ScaffoldMessenger.of(
      sheetContext,
    ).showSnackBar(AppSnackBar.error(sheetContext, message));
  }

  Future<void> _showDeleteConfirmation(Herd herd) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Herd',
      message:
          'Are you sure you want to delete "${herd.name}"? This action cannot be undone.',
    );
    if (confirmed == true) {
      SuccessFeedback.deleted();
      context.read<HerdBloc>().add(DeleteHerdEvent(herd.id));
    }
  }
}