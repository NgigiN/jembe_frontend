import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/widgets/crud/cost_category_type_selector.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/utils/source_context_resolver.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, this.sourceType});
  final String? sourceType;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  @override
  void initState() {
    super.initState();
    context.read<ActivityBloc>().add(
      GetActivitiesEvent(sourceType: widget.sourceType),
    );
    context.read<HerdBloc>().add(GetHerdsEvent());
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<LandBloc>().add(GetLandsEvent());
    context.read<CostCategoryBloc>().add(
      const GetCostCategoriesEvent(category: 'activity'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seasonState = context.watch<SeasonBloc>().state;
    final seasons =
        seasonState is SeasonLoaded ? seasonState.seasons : <Season>[];
    final landState = context.watch<LandBloc>().state;
    final lands = landState is LandLoaded ? landState.lands : <Land>[];
    final herdState = context.watch<HerdBloc>().state;
    final herds = herdState is HerdLoaded ? herdState.herds : <Herd>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Management'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<ActivityBloc, ActivityState>(
        builder: (context, state) {
          if (state is ActivityLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ActivityError) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<ActivityBloc>().add(
                GetActivitiesEvent(sourceType: widget.sourceType),
              ),
            );
          }

          if (state is ActivityLoaded) {
            if (state.activities.isEmpty) {
              return const EntityEmptyView(
                icon: Icons.work,
                title: 'No activities registered yet',
                subtitle: 'Tap the + button to add your first activity',
              );
            }

            return ListView.builder(
              padding: context.scrollListPadding(forFab: true),
              itemCount: state.activities.length,
              itemBuilder: (context, index) {
                final activity = state.activities[index];
                final isPlant = activity.sourceType == 'plant';
                final categoryColor = isPlant
                    ? AppColors.plantCategory
                    : AppColors.animalCategory;
                final subtitle = isPlant
                    ? '${seasonName(seasons, activity.sourceId)} · ${landNameForSeason(seasons, lands, activity.sourceId)}'
                    : herdName(herds, activity.sourceId);

                return EntityCard(
                  icon: Icons.work,
                  iconColor: categoryColor,
                  title: activity.type,
                  subtitle: '$subtitle · ${_formatDate(activity.date)}',
                  trailing: Text(
                    'Ksh ${activity.cost.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  onTap: () => _showActivityDetails(
                    context,
                    activity,
                    seasons: seasons,
                    lands: lands,
                    herds: herds,
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => _showAddActivityDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showActivityDetails(
    BuildContext context,
    Activity activity, {
    required List<Season> seasons,
    required List<Land> lands,
    required List<Herd> herds,
  }) {
    final isPlant = activity.sourceType == 'plant';
    EntityDetailsSheet.show(
      context: context,
      title: activity.type,
      badgeLabel: activity.sourceType.toUpperCase(),
      badgeColor:
          isPlant ? AppColors.plantCategory : AppColors.animalCategory,
      details: [
        if (isPlant) ...[
          EntityDetailRow('Season', seasonName(seasons, activity.sourceId)),
          EntityDetailRow(
            'Land',
            landNameForSeason(seasons, lands, activity.sourceId),
          ),
        ] else
          EntityDetailRow('Herd', herdName(herds, activity.sourceId)),
        EntityDetailRow(
          'Cost',
          'Ksh ${activity.cost.toStringAsFixed(2)}',
          isPrimary: true,
        ),
        EntityDetailRow('Date', _formatDate(activity.date)),
        if (activity.details != null && activity.details!.isNotEmpty)
          EntityDetailRow('Details', activity.details!),
        if (activity.notes != null && activity.notes!.isNotEmpty)
          EntityDetailRow('Notes', activity.notes!),
      ],
      onEdit: () => _showEditActivityDialog(context, activity),
      onDelete: () => _showDeleteConfirmation(context, activity),
    );
  }

  Future<void> _showAddActivityDialog(BuildContext context) async {
    final typeController = TextEditingController();
    final costController = TextEditingController();
    final detailsController = TextEditingController();
    final seasonState = context.read<SeasonBloc>().state;
    final seasons = seasonState is SeasonLoaded
        ? seasonState.seasons
        : <Season>[];

    final landState = context.read<LandBloc>().state;
    final lands = landState is LandLoaded ? landState.lands : <Land>[];

    final herdState = context.read<HerdBloc>().state;
    final herds = herdState is HerdLoaded ? herdState.herds : <Herd>[];

    String? selectedSourceType = 'plant';
    String? selectedSeasonId;
    String? selectedHerdId;
    DateTime? selectedDate = DateTime.now();

    if (seasons.isEmpty && herds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one season or herd first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => EntityFormSheet.container(
          context: context,
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add New Activity',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: EntityFormSheet.scrollableForm(
                    context: context,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedSourceType,
                          decoration: const InputDecoration(
                            labelText: 'Source Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'plant',
                              child: Text('Plant'),
                            ),
                            DropdownMenuItem(
                              value: 'animal',
                              child: Text('Animal'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedSourceType = value ?? 'plant';
                              selectedSeasonId = null;
                              selectedHerdId = null;
                              typeController.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (selectedSourceType == 'plant')
                          DropdownButtonFormField<String>(
                            initialValue: selectedSeasonId,
                            decoration: const InputDecoration(
                              labelText: 'Select Season *',
                              border: OutlineInputBorder(),
                            ),
                            items: seasons
                                .map<DropdownMenuItem<String>>((season) {
                              return DropdownMenuItem<String>(
                                value: season.id,
                                child: Text(seasonDropdownLabel(season, lands)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSeasonId = value;
                              });
                            },
                          ),
                        if (selectedSourceType == 'animal')
                          BlocBuilder<HerdBloc, HerdState>(
                            builder: (context, herdState) {
                              if (herdState is HerdLoaded) {
                                final herds = herdState.herds;
                                return DropdownButtonFormField<String>(
                                  initialValue: selectedHerdId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Herd *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: herds.map((herd) {
                                    return DropdownMenuItem<String>(
                                      value: herd.id,
                                      child: Text(
                                        '${herd.name} (${herd.location})',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedHerdId = value;
                                    });
                                  },
                                );
                              }
                              return const CircularProgressIndicator();
                            },
                          ),
                        if (selectedSourceType == 'plant' ||
                            selectedSourceType == 'animal')
                          const SizedBox(height: 16),
                        CostCategoryTypeSelector(
                          categoryKind: 'activity',
                          sourceType: selectedSourceType!,
                          selectedType: typeController.text,
                          labelText: 'Activity Type *',
                          hintText: 'Select activity type',
                          addButtonBackgroundColor: Colors.green.shade50,
                          onTypeChanged: (value) {
                            setState(() {
                              typeController.text = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Date *'),
                          subtitle: Text(
                            selectedDate != null
                                ? _formatDate(selectedDate!)
                                : 'Select date',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: costController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cost (Optional)',
                            border: OutlineInputBorder(),
                            prefixText: 'Ksh ',
                            hintText: '0.00',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: detailsController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Details (Optional)',
                            border: OutlineInputBorder(),
                            hintText: 'Describe the activity details...',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedSourceType == 'plant' &&
                          selectedSeasonId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a season'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedSourceType == 'animal' &&
                          selectedHerdId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a herd'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (typeController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please select an activity type'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a date'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final cost = double.tryParse(
                              costController.text.trim()) ??
                          0.0;
                      if (cost < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cost cannot be negative'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final sourceId = selectedSourceType == 'plant'
                          ? selectedSeasonId!
                          : selectedHerdId!;

                      final activity = ActivityModel.create(
                        sourceType: selectedSourceType!,
                        sourceId: sourceId,
                        animalId:
                            selectedSourceType == 'animal' ? 0 : null,
                        type: typeController.text.trim(),
                        details: detailsController.text.trim().isEmpty
                            ? null
                            : detailsController.text.trim(),
                        cost: cost,
                        date: selectedDate!,
                        notes: detailsController.text.trim().isEmpty
                            ? null
                            : detailsController.text.trim(),
                      );
                      context.read<ActivityBloc>().add(
                        AddActivityEvent(activity),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Add Activity',
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

  Future<void> _showEditActivityDialog(
    BuildContext context,
    Activity activity,
  ) async {
    final descriptionController = TextEditingController(
      text: activity.details ?? '',
    );
    final costController = TextEditingController(
      text: activity.cost.toString(),
    );
    final seasonState = context.read<SeasonBloc>().state;
    final seasons = seasonState is SeasonLoaded
        ? seasonState.seasons
        : <Season>[];

    final landState = context.read<LandBloc>().state;
    final lands = landState is LandLoaded ? landState.lands : <Land>[];

    final herdState = context.read<HerdBloc>().state;
    final herds = herdState is HerdLoaded ? herdState.herds : <Herd>[];

    String? selectedSourceType = activity.sourceType;
    var selectedSeasonId = activity.sourceType == 'plant'
        ? activity.sourceId
        : null;
    var selectedHerdId = activity.sourceType == 'animal'
        ? activity.sourceId
        : null;
    String? selectedType = activity.type;
    DateTime? selectedDate = activity.date;

    if ((selectedSourceType == 'plant' && seasons.isEmpty) ||
        (selectedSourceType == 'animal' && herds.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No seasons or herds available for editing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => EntityFormSheet.container(
          context: context,
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Activity',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: EntityFormSheet.scrollableForm(
                    context: context,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedSourceType,
                          decoration: const InputDecoration(
                            labelText: 'Source Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'plant',
                              child: Text('Plant'),
                            ),
                            DropdownMenuItem(
                              value: 'animal',
                              child: Text('Animal'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedSourceType = value ?? 'plant';
                              if (selectedSourceType == 'plant') {
                                selectedHerdId = null;
                              } else {
                                selectedSeasonId = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (selectedSourceType == 'plant')
                          DropdownButtonFormField<String>(
                            initialValue: selectedSeasonId,
                            decoration: const InputDecoration(
                              labelText: 'Select Season *',
                              border: OutlineInputBorder(),
                            ),
                            items: seasons
                                .map<DropdownMenuItem<String>>((season) {
                              return DropdownMenuItem<String>(
                                value: season.id,
                                child: Text(seasonDropdownLabel(season, lands)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSeasonId = value;
                              });
                            },
                          ),
                        if (selectedSourceType == 'animal')
                          BlocBuilder<HerdBloc, HerdState>(
                            builder: (context, herdState) {
                              if (herdState is HerdLoaded) {
                                final herds = herdState.herds;
                                return DropdownButtonFormField<String>(
                                  initialValue: selectedHerdId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Herd *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: herds.map((herd) {
                                    return DropdownMenuItem<String>(
                                      value: herd.id,
                                      child: Text(
                                        '${herd.name} (${herd.location})',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedHerdId = value;
                                    });
                                  },
                                );
                              }
                              return const CircularProgressIndicator();
                            },
                          ),
                        if (selectedSourceType == 'plant' ||
                            selectedSourceType == 'animal')
                          const SizedBox(height: 16),
                        CostCategoryTypeSelector(
                          categoryKind: 'activity',
                          sourceType: selectedSourceType!,
                          selectedType: selectedType ?? '',
                          labelText: 'Activity Type *',
                          addButtonBackgroundColor: Colors.blue.shade50,
                          onTypeChanged: (value) {
                            setState(() {
                              selectedType = value.isEmpty ? null : value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            hintText:
                                'Enter activity description (optional)',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: costController,
                          decoration: const InputDecoration(
                            labelText: 'Cost',
                            border: OutlineInputBorder(),
                            prefixText: 'Ksh ',
                            hintText: '0.00',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Date *'),
                          subtitle: Text(
                            selectedDate != null
                                ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                : 'Select date',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedSourceType == 'plant' &&
                          selectedSeasonId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a season'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedSourceType == 'animal' &&
                          selectedHerdId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a herd'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please select an activity type'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a date'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final cost = double.tryParse(
                              costController.text.trim()) ??
                          0.0;
                      if (cost < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cost cannot be negative'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final sourceId = selectedSourceType == 'plant'
                          ? selectedSeasonId!
                          : selectedHerdId!;

                      final updatedActivity = ActivityModel(
                        id: activity.id,
                        sourceType: selectedSourceType!,
                        sourceId: sourceId,
                        animalId:
                            selectedSourceType == 'animal' ? 0 : null,
                        type: selectedType!,
                        details: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        cost: cost,
                        date: selectedDate!,
                        notes: activity.notes,
                        createdAt: activity.createdAt,
                        updatedAt: DateTime.now(),
                      );

                      context.read<ActivityBloc>().add(
                        UpdateActivityEvent(updatedActivity),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Activity updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Update Activity',
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

  Future<void> _showDeleteConfirmation(
      BuildContext context, Activity activity) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Activity',
      message:
          'Are you sure you want to delete this ${activity.type.toLowerCase()} activity? This action cannot be undone.',
    );
    if (confirmed ?? false) {
      context.read<ActivityBloc>().add(
        DeleteActivityEvent(activity.id),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${activity.type} activity deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

}
