import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';

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
    context.read<CostCategoryBloc>().add(
      const GetCostCategoriesEvent(category: 'activity'),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: TextStyle(fontSize: 16, color: Colors.red.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ActivityBloc>().add(
                        GetActivitiesEvent(sourceType: widget.sourceType),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ActivityLoaded) {
            if (state.activities.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.work, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No activities registered yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first activity',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.activities.length,
              itemBuilder: (context, index) {
                final activity = state.activities[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Icon(Icons.work, color: Colors.red.shade700),
                    ),
                    title: Text(
                      activity.type,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: ${_formatDate(activity.date)}'),
                        Text('Cost: Ksh ${activity.cost.toStringAsFixed(2)}'),
                        if (activity.details != null &&
                            activity.details!.isNotEmpty)
                          Text('Details: ${activity.details}'),
                        Text(
                          'Created: ${_formatDate(activity.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditActivityDialog(context, activity);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context, activity);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          return const Center(child: Text('Something went wrong'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddActivityDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _showAddActivityDialog(BuildContext context) async {
    final typeController = TextEditingController();
    final costController = TextEditingController();
    final detailsController = TextEditingController();

    // Ensure data is being loaded
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<HerdBloc>().add(GetHerdsEvent());
    context.read<CostCategoryBloc>().add(
      const GetCostCategoriesEvent(category: 'activity'),
    );

    String? selectedSourceType = 'plant';
    String? selectedSeasonId;
    String? selectedHerdId;
    DateTime? selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add New Activity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
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
                          BlocBuilder<SeasonBloc, SeasonState>(
                            builder: (context, seasonState) {
                              if (seasonState is SeasonLoading) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final seasons = seasonState is SeasonLoaded
                                  ? seasonState.seasons
                                  : <Season>[];
                              return DropdownButtonFormField<String>(
                                value: selectedSeasonId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Season *',
                                  border: OutlineInputBorder(),
                                ),
                                items: seasons.map((season) {
                                  return DropdownMenuItem<String>(
                                    value: season.id,
                                    child: Text(season.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedSeasonId = value;
                                  });
                                },
                              );
                            },
                          ),
                        if (selectedSourceType == 'animal')
                          BlocBuilder<HerdBloc, HerdState>(
                            builder: (context, herdState) {
                              if (herdState is HerdLoading) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final herds = herdState is HerdLoaded
                                  ? herdState.herds
                                  : <Herd>[];
                              return DropdownButtonFormField<String>(
                                value: selectedHerdId,
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
                            },
                          ),
                        if (selectedSourceType == 'plant' ||
                            selectedSourceType == 'animal')
                          const SizedBox(height: 16),
                        BlocBuilder<CostCategoryBloc, CostCategoryState>(
                          builder: (context, costCategoryState) {
                            if (costCategoryState is CostCategoryLoading &&
                                costCategoryState.categories.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final allCategories = costCategoryState.categories;
                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'Activity Type *',
                                      border: OutlineInputBorder(),
                                      hintText: 'Select activity type',
                                    ),
                                    items: allCategories
                                        .where(
                                          (c) => c.type == selectedSourceType,
                                        )
                                        .map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category.name,
                                            child: Text(category.name),
                                          );
                                        })
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        typeController.text = value ?? '';
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () =>
                                      _showCreateActivityTypeDialog(
                                        context,
                                        selectedSourceType!,
                                      ),
                                  icon: const Icon(Icons.add_circle_outline),
                                  tooltip: 'Add new activity type',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green.shade50,
                                  ),
                                ),
                              ],
                            );
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
                            content: Text('Please select an activity type'),
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

                      final cost =
                          double.tryParse(costController.text.trim()) ?? 0.0;
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
                        animalId: selectedSourceType == 'animal' ? 0 : null,
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

    // Ensure data is being loaded
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<HerdBloc>().add(GetHerdsEvent());
    context.read<CostCategoryBloc>().add(
      const GetCostCategoriesEvent(category: 'activity'),
    );

    String? selectedSourceType = activity.sourceType;
    var selectedSeasonId = activity.sourceType == 'plant'
        ? activity.sourceId
        : null;
    var selectedHerdId = activity.sourceType == 'animal'
        ? activity.sourceId
        : null;
    String? selectedType = activity.type;
    DateTime? selectedDate = activity.date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Activity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
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
                          BlocBuilder<SeasonBloc, SeasonState>(
                            builder: (context, seasonState) {
                              if (seasonState is SeasonLoading) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final seasons = seasonState is SeasonLoaded
                                  ? seasonState.seasons
                                  : <Season>[];
                              return DropdownButtonFormField<String>(
                                initialValue: selectedSeasonId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Season *',
                                  border: OutlineInputBorder(),
                                ),
                                items: seasons.map<DropdownMenuItem<String>>((
                                  season,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: season.id,
                                    child: Text(season.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedSeasonId = value;
                                  });
                                },
                              );
                            },
                          ),
                        if (selectedSourceType == 'animal')
                          BlocBuilder<HerdBloc, HerdState>(
                            builder: (context, herdState) {
                              if (herdState is HerdLoading) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final herds = herdState is HerdLoaded
                                  ? herdState.herds
                                  : <Herd>[];
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
                            },
                          ),
                        if (selectedSourceType == 'plant' ||
                            selectedSourceType == 'animal')
                          const SizedBox(height: 16),
                        BlocBuilder<CostCategoryBloc, CostCategoryState>(
                          builder: (context, costCategoryState) {
                            if (costCategoryState is CostCategoryLoading &&
                                costCategoryState.categories.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final allCategories = costCategoryState.categories;
                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedType,
                                    decoration: const InputDecoration(
                                      labelText: 'Activity Type *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: allCategories
                                        .where(
                                          (c) => c.type == selectedSourceType,
                                        )
                                        .map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category.name,
                                            child: Text(category.name),
                                          );
                                        })
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedType = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () =>
                                      _showCreateActivityTypeDialog(
                                        context,
                                        selectedSourceType!,
                                      ),
                                  icon: const Icon(Icons.add_circle_outline),
                                  tooltip: 'Add new activity type',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue.shade50,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            hintText: 'Enter activity description (optional)',
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
                              initialDate: selectedDate ?? DateTime.now(),
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
                            content: Text('Please select an activity type'),
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

                      final cost =
                          double.tryParse(costController.text.trim()) ?? 0.0;
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
                        animalId: selectedSourceType == 'animal' ? 0 : null,
                        type: selectedType!,
                        details: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        cost: cost,
                        date: selectedDate!,
                        notes: activity.notes, // Preserve existing notes
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
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
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

  void _showDeleteConfirmation(BuildContext context, Activity activity) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Activity'),
          content: Text(
            'Are you sure you want to delete this ${activity.type.toLowerCase()} activity? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<ActivityBloc>().add(
                  DeleteActivityEvent(activity.id),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${activity.type} activity deleted successfully',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateActivityTypeDialog(BuildContext context, String sourceType) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New ${sourceType == 'plant' ? 'Plant' : 'Animal'} Activity Type',
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Activity Type Name',
            hintText: 'e.g., Custom Activity',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              context.read<CostCategoryBloc>().add(
                AddCostCategoryEvent(
                  name: nameController.text.trim(),
                  type: sourceType,
                  category: 'activity',
                ),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${nameController.text.trim()} added successfully',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
