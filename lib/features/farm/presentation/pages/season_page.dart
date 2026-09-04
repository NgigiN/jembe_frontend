import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
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
import 'package:farm_tracker/core/widgets/crud/entity_picker_with_add.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/land_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/plant_page.dart';
import 'package:farm_tracker/features/farm/presentation/utils/source_context_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the standard "Add New Season" form and resolves once it closes:
/// the new season's id if the add succeeded, or null if the sheet was
/// dismissed without submitting. Plant and Land are read reactively (not a
/// one-time snapshot) so adding one inline via the pickers' "+" buttons
/// makes it immediately selectable without closing and reopening the sheet.
Future<String?> showAddSeasonDialog(BuildContext context) async {
  final seasonBloc = context.read<SeasonBloc>();
  final landBloc = context.read<LandBloc>();
  final plantBloc = context.read<PlantBloc>();
  final beforeIds = seasonBloc.state.seasons.map((season) => season.id).toSet();
  String? newId;

  final subscription = seasonBloc.stream.listen((state) {
    if (state is SeasonLoaded && state.successMessage == 'Season created') {
      for (final season in state.seasons) {
        if (!beforeIds.contains(season.id)) {
          newId = season.id;
          break;
        }
      }
    }
  });

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  String? selectedPlantId;
  String? selectedLandId;
  var submitting = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => BlocBuilder<PlantBloc, PlantState>(
        bloc: plantBloc,
        builder: (plantBuilderContext, plantState) {
          final plants = plantState is PlantLoaded ? plantState.plants : <Plant>[];
          return BlocBuilder<LandBloc, LandState>(
            bloc: landBloc,
            builder: (landBuilderContext, landState) {
              final lands = landState is LandLoaded ? landState.lands : <Land>[];

              return EntityFormSheet.container(
                context: sheetContext,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add New Season',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.pop(sheetContext),
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
                            child: _SeasonPageState._seasonFormFields(
                              context: sheetContext,
                              nameController: nameController,
                              plants: plants,
                              lands: lands,
                              selectedPlantId: selectedPlantId,
                              selectedLandId: selectedLandId,
                              selectedStartDate: selectedStartDate,
                              selectedEndDate: selectedEndDate,
                              onPlantChanged: (value) =>
                                  setSheetState(() => selectedPlantId = value),
                              onLandChanged: (value) =>
                                  setSheetState(() => selectedLandId = value),
                              onStartDateChanged: (value) =>
                                  setSheetState(() => selectedStartDate = value),
                              onEndDateChanged: (value) =>
                                  setSheetState(() => selectedEndDate = value),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (!(formKey.currentState?.validate() ??
                                      false)) {
                                    return;
                                  }
                                  setSheetState(() => submitting = true);
                                  final ok = await _submitAddSeason(
                                    seasonBloc: seasonBloc,
                                    sheetContext: sheetContext,
                                    nameController: nameController,
                                    selectedPlantId: selectedPlantId,
                                    selectedLandId: selectedLandId,
                                    selectedStartDate: selectedStartDate,
                                    selectedEndDate: selectedEndDate,
                                  );
                                  if (!sheetContext.mounted) return;
                                  if (ok) {
                                    SuccessFeedback.saved();
                                    Navigator.pop(sheetContext);
                                  } else {
                                    setSheetState(() => submitting = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Add Season',
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
          );
        },
      ),
    ),
  );

  await subscription.cancel();
  return newId;
}

/// Validates and submits the "Add New Season" form. A top-level function
/// (not inlined in the button's onPressed) for the same reason as
/// `_submitAddHerd` in herd_page.dart: the selected-date variables are
/// captured, mutable closure state, so Dart won't promote their
/// nullability after a null check inline — passing them as plain
/// parameters here lets it. Returns true once the bloc confirms the season
/// was added; the caller plays the success feedback and pops the sheet
/// only then.
Future<bool> _submitAddSeason({
  required SeasonBloc seasonBloc,
  required BuildContext sheetContext,
  required TextEditingController nameController,
  required String? selectedPlantId,
  required String? selectedLandId,
  required DateTime? selectedStartDate,
  required DateTime? selectedEndDate,
}) async {
  final userId = await UserUtils.getCurrentUserId();
  if (userId == null) {
    ScaffoldMessenger.of(sheetContext).showSnackBar(
      AppSnackBar.error(sheetContext, 'User not authenticated'),
    );
    return false;
  }

  final season = SeasonModel.create(
    userId: userId,
    name: sanitizeText(nameController.text),
    plantId: selectedPlantId!,
    landId: selectedLandId!,
    startDate: selectedStartDate!,
    endDate: selectedEndDate,
  );
  seasonBloc.add(AddSeasonEvent(season));
  final s = await seasonBloc.stream.firstWhere(
    (s) => (s is SeasonLoaded && s.successMessage != null) || s is SeasonError,
  );
  return s is SeasonLoaded;
}

class SeasonPage extends StatefulWidget {
  const SeasonPage({super.key});

  @override
  State<SeasonPage> createState() => _SeasonPageState();
}

class _SeasonPageState extends State<SeasonPage> {
  @override
  void initState() {
    super.initState();
    final seasonBloc = context.read<SeasonBloc>();
    if (seasonBloc.state is! SeasonLoaded) {
      seasonBloc.add(GetSeasonsEvent());
    }
    final landBloc = context.read<LandBloc>();
    if (landBloc.state is! LandLoaded) {
      landBloc.add(GetLandsEvent());
    }
    final plantBloc = context.read<PlantBloc>();
    if (plantBloc.state is! PlantLoaded) {
      plantBloc.add(GetPlantsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final landState = context.watch<LandBloc>().state;
    final lands = landState is LandLoaded ? landState.lands : <Land>[];
    final plantState = context.watch<PlantBloc>().state;
    final plants = plantState is PlantLoaded ? plantState.plants : <Plant>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Season Management'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final seasonBloc = context.read<SeasonBloc>()
            ..add(GetSeasonsEvent());
          context.read<LandBloc>().add(GetLandsEvent());
          context.read<PlantBloc>().add(GetPlantsEvent());
          await seasonBloc.stream.firstWhere(
            (s) => s is SeasonLoaded || s is SeasonError,
          );
        },
        child: BlocConsumer<SeasonBloc, SeasonState>(
        listener: (context, state) {
          if (state is SeasonLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(context, state.successMessage!),
            );
          } else if (state is SeasonError && state.seasons.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(context, state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is SeasonLoading && state.seasons.isEmpty) {
            return const SkeletonEntityList(icon: Icons.calendar_today);
          }

          if (state is SeasonError && state.seasons.isEmpty) {
            return _scrollableEmptyState(
              EntityErrorView(
                message: state.message,
                onRetry: () => context.read<SeasonBloc>().add(GetSeasonsEvent()),
              ),
            );
          }

          final seasons = state.seasons;
          if (seasons.isEmpty) {
            return _scrollableEmptyState(
              const EntityEmptyView(
                icon: Icons.calendar_today,
                title: 'No seasons registered yet',
                subtitle: 'Tap the + button to add your first season',
              ),
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.scrollListPadding(forFab: true),
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];
              return EntityCard(
                icon: Icons.calendar_today,
                iconColor: AppColors.plantCategory,
                title: season.name,
                subtitle:
                    '${landName(lands, season.landId)} · Start: ${_formatDate(season.startDate)}',
                onTap: () => _showSeasonDetails(
                  season,
                  lands: lands,
                  plants: plants,
                ),
              );
            },
          );
        },
        ),
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: _showAddSeasonDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// Makes a non-scrollable empty/error state (a centered icon+text column)
  /// pullable: [RefreshIndicator] needs a scrollable descendant to detect
  /// the pull gesture, even when there's nothing to scroll.
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

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSeasonDetails(
    Season season, {
    required List<Land> lands,
    required List<Plant> plants,
  }) {
    EntityDetailsSheet.show(
      context: context,
      title: season.name,
      details: [
        EntityDetailRow('Plant', plantName(plants, season.plantId)),
        EntityDetailRow('Land', landName(lands, season.landId)),
        EntityDetailRow('Start Date', _formatDate(season.startDate)),
        EntityDetailRow(
          'End Date',
          season.endDate != null ? _formatDate(season.endDate!) : '—',
        ),
      ],
      onEdit: () => _showEditSeasonDialog(season),
      onDelete: () => _showDeleteConfirmation(season),
    );
  }

  void _showAddSeasonDialog() {
    showAddSeasonDialog(context);
  }

  void _showEditSeasonDialog(Season season) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: season.name);
    DateTime? selectedStartDate = season.startDate;
    var selectedEndDate = season.endDate != null && season.endDate!.year > 2000
        ? season.endDate
        : null;
    String? selectedPlantId = season.plantId;
    String? selectedLandId = season.landId;
    var submitting = false;

    final landState = context.read<LandBloc>().state;
    final lands = landState is LandLoaded ? landState.lands : <Land>[];

    final plantState = context.read<PlantBloc>().state;
    final plants = plantState is PlantLoaded ? plantState.plants : <Plant>[];

    if (lands.isEmpty || plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No lands or plants available for editing'),
          backgroundColor: context.statusColors.warning,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntityFormSheet.container(
          context: sheetContext,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Season',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed:
                          submitting ? null : () => Navigator.pop(sheetContext),
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
                      child: _seasonFormFields(
                        context: sheetContext,
                        nameController: nameController,
                        plants: plants,
                        lands: lands,
                        selectedPlantId: selectedPlantId,
                        selectedLandId: selectedLandId,
                        selectedStartDate: selectedStartDate,
                        selectedEndDate: selectedEndDate,
                        onPlantChanged: (value) =>
                            setSheetState(() => selectedPlantId = value),
                        onLandChanged: (value) =>
                            setSheetState(() => selectedLandId = value),
                        onStartDateChanged: (value) =>
                            setSheetState(() => selectedStartDate = value),
                        onEndDateChanged: (value) =>
                            setSheetState(() => selectedEndDate = value),
                        showClearEndDate: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ??
                                false)) {
                              return;
                            }

                            final updatedSeason = SeasonModel(
                              id: season.id,
                              userId: season.userId,
                              name: sanitizeText(nameController.text),
                              plantId: selectedPlantId!,
                              landId: selectedLandId!,
                              startDate: selectedStartDate!,
                              endDate: selectedEndDate,
                              createdAt: season.createdAt,
                              updatedAt: DateTime.now(),
                            );

                            setSheetState(() => submitting = true);

                            final bloc = context.read<SeasonBloc>()
                              ..add(UpdateSeasonEvent(updatedSeason));
                            final s = await bloc.stream.firstWhere(
                              (s) =>
                                  (s is SeasonLoaded &&
                                      s.successMessage != null) ||
                                  s is SeasonError,
                            );
                            if (!sheetContext.mounted) return;
                            if (s is SeasonLoaded) {
                              SuccessFeedback.saved();
                              Navigator.pop(sheetContext);
                            } else {
                              setSheetState(() => submitting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(sheetContext).colorScheme.primary,
                      foregroundColor:
                          Theme.of(sheetContext).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                      'Update Season',
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
        ),
      ),
    );
  }

  static Widget _seasonFormFields({
    required BuildContext context,
    required TextEditingController nameController,
    required List<Plant> plants,
    required List<Land> lands,
    required String? selectedPlantId,
    required String? selectedLandId,
    required DateTime? selectedStartDate,
    required DateTime? selectedEndDate,
    required ValueChanged<String?> onPlantChanged,
    required ValueChanged<String?> onLandChanged,
    required ValueChanged<DateTime?> onStartDateChanged,
    required ValueChanged<DateTime?> onEndDateChanged,
    bool showClearEndDate = false,
  }) {
    final endDate = selectedEndDate;
    final hasValidEndDate = endDate != null && endDate.year > 2000;

    return Column(
      children: [
        ValidatedNameField(
          controller: nameController,
          labelText: 'Season Name *',
          validator: (value) => requiredName(value, fieldLabel: 'Season name'),
        ),
        const SizedBox(height: 16),
        EntityPickerWithAdd<Plant>(
          items: plants,
          selectedId: selectedPlantId,
          idOf: (plant) => plant.id,
          labelOf: (plant) {
            final variety = plant.variety ?? '';
            return variety.isNotEmpty
                ? '${plant.name} ($variety)'
                : plant.name;
          },
          labelText: 'Select Plant *',
          validator: (value) =>
              requiredSelection(value, fieldLabel: 'plant'),
          onChanged: onPlantChanged,
          onAddNew: showAddPlantDialog,
        ),
        const SizedBox(height: 16),
        EntityPickerWithAdd<Land>(
          items: lands,
          selectedId: selectedLandId,
          idOf: (land) => land.id,
          labelOf: (land) {
            final location = land.location ?? '';
            return location.isNotEmpty
                ? '${land.name} ($location)'
                : land.name;
          },
          labelText: 'Select Land *',
          validator: (value) =>
              requiredSelection(value, fieldLabel: 'land'),
          onChanged: onLandChanged,
          onAddNew: showAddLandDialog,
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
          initialValue: hasValidEndDate ? selectedEndDate : null,
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
                  hasValidEndDate
                      ? _formatDate(endDate)
                      : 'Select end date (optional)',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showClearEndDate && hasValidEndDate)
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
                  final validEndDate = hasValidEndDate ? selectedEndDate : null;
                  final initialDate =
                      validEndDate ?? selectedStartDate ?? DateTime.now();
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
      ],
    );
  }

  Future<void> _showDeleteConfirmation(Season season) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Season',
      message:
          'Are you sure you want to delete "${season.name}"? This action cannot be undone.',
    );
    if (confirmed ?? false) {
      SuccessFeedback.deleted();
      context.read<SeasonBloc>().add(DeleteSeasonEvent(season.id));
    }
  }
}
