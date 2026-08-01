import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
import 'package:farm_tracker/features/farm/presentation/utils/source_context_resolver.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';

class SeasonPage extends StatefulWidget {
  const SeasonPage({super.key});

  @override
  State<SeasonPage> createState() => _SeasonPageState();
}

class _SeasonPageState extends State<SeasonPage> {
  @override
  void initState() {
    super.initState();
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<LandBloc>().add(GetLandsEvent());
    context.read<PlantBloc>().add(GetPlantsEvent());
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
      body: BlocConsumer<SeasonBloc, SeasonState>(
        listener: (context, state) {
          if (state is SeasonLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(state.successMessage!),
            );
          } else if (state is SeasonError && state.seasons.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is SeasonLoading && state.seasons.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SeasonError && state.seasons.isEmpty) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<SeasonBloc>().add(GetSeasonsEvent()),
            );
          }

          final seasons = state.seasons;
          if (seasons.isEmpty) {
            return EntityEmptyView(
              icon: Icons.calendar_today,
              title: 'No seasons registered yet',
              subtitle: 'Tap the + button to add your first season',
            );
          }

          return ListView.builder(
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
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => _showAddSeasonDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    DateTime? selectedStartDate;
    DateTime? selectedEndDate;
    String? selectedPlantId;
    String? selectedLandId;

    final landState = context.read<LandBloc>().state;
    final lands = landState is LandLoaded ? landState.lands : <Land>[];

    final plantState = context.read<PlantBloc>().state;
    final plants = plantState is PlantLoaded ? plantState.plants : <Plant>[];

    if (lands.isEmpty || plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one land and one plant first'),
          backgroundColor: Colors.orange,
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
                      'Add New Season',
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
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
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

                      final season = SeasonModel.create(
                        userId: userId,
                        name: sanitizeText(nameController.text),
                        plantId: selectedPlantId!,
                        landId: selectedLandId!,
                        startDate: selectedStartDate!,
                        endDate: selectedEndDate,
                      );
                      context.read<SeasonBloc>().add(AddSeasonEvent(season));
                      Navigator.pop(sheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
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
        ),
      ),
    );
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

    final landState = context.read<LandBloc>().state;
    final lands = landState is LandLoaded ? landState.lands : <Land>[];

    final plantState = context.read<PlantBloc>().state;
    final plants = plantState is PlantLoaded ? plantState.plants : <Plant>[];

    if (lands.isEmpty || plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No lands or plants available for editing'),
          backgroundColor: Colors.orange,
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
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
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
                      context.read<SeasonBloc>().add(
                        UpdateSeasonEvent(updatedSeason),
                      );
                      Navigator.pop(sheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(sheetContext).colorScheme.primary,
                      foregroundColor:
                          Theme.of(sheetContext).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
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

  Widget _seasonFormFields({
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
        DropdownButtonFormField<String>(
          initialValue: selectedPlantId,
          decoration: const InputDecoration(
            labelText: 'Select Plant *',
            border: OutlineInputBorder(),
          ),
          items: plants.map((plant) {
            final name = plant.name;
            final variety = plant.variety ?? '';
            final displayName =
                variety.isNotEmpty ? '$name ($variety)' : name;
            return DropdownMenuItem<String>(
              value: plant.id,
              child: Text(displayName),
            );
          }).toList(),
          validator: (value) =>
              requiredSelection(value, fieldLabel: 'plant'),
          onChanged: onPlantChanged,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: selectedLandId,
          decoration: const InputDecoration(
            labelText: 'Select Land *',
            border: OutlineInputBorder(),
          ),
          items: lands.map((land) {
            final name = land.name;
            final location = land.location ?? '';
            final displayName =
                location.isNotEmpty ? '$name ($location)' : name;
            return DropdownMenuItem<String>(
              value: land.id,
              child: Text(displayName),
            );
          }).toList(),
          validator: (value) =>
              requiredSelection(value, fieldLabel: 'land'),
          onChanged: onLandChanged,
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

  void _showDeleteConfirmation(Season season) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Season',
      message:
          'Are you sure you want to delete "${season.name}"? This action cannot be undone.',
    );
    if (confirmed == true) {
      context.read<SeasonBloc>().add(DeleteSeasonEvent(season.id));
    }
  }
}
