import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
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
      body: BlocBuilder<SeasonBloc, SeasonState>(
        builder: (context, state) {
          if (state is SeasonLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SeasonError) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<SeasonBloc>().add(GetSeasonsEvent()),
            );
          }

          if (state is SeasonLoaded) {
            if (state.seasons.isEmpty) {
              return EntityEmptyView(
                icon: Icons.calendar_today,
                title: 'No seasons registered yet',
                subtitle: 'Tap the + button to add your first season',
              );
            }

            return ListView.builder(
              padding: context.scrollListPadding(forFab: true),
              itemCount: state.seasons.length,
              itemBuilder: (context, index) {
                final season = state.seasons[index];
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
          }

          return const SizedBox.shrink();
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Season Name *',
                            border: OutlineInputBorder(),
                          ),
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
                            final displayName = variety.isNotEmpty
                                ? '$name ($variety)'
                                : name;
                            return DropdownMenuItem<String>(
                              value: plant.id,
                              child: Text(displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedPlantId = value;
                            });
                          },
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
                            final displayName = location.isNotEmpty
                                ? '$name ($location)'
                                : name;
                            return DropdownMenuItem<String>(
                              value: land.id,
                              child: Text(displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLandId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Start Date *'),
                          subtitle: Text(
                            selectedStartDate != null
                                ? _formatDate(selectedStartDate!)
                                : 'Select start date',
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
                                selectedStartDate = date;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('End Date (Optional)'),
                          subtitle: Text(
                            selectedEndDate != null
                                ? _formatDate(selectedEndDate!)
                                : 'Select end date (optional)',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  selectedStartDate ?? DateTime.now(),
                              firstDate:
                                  selectedStartDate ?? DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() {
                                selectedEndDate = date;
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
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Season name is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedPlantId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a plant'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedLandId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a land'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedStartDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a start date'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final userId = await UserUtils.getCurrentUserId();
                      if (userId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User not authenticated'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final season = SeasonModel.create(
                        userId: userId,
                        name: nameController.text.trim(),
                        plantId: selectedPlantId!,
                        landId: selectedLandId!,
                        startDate: selectedStartDate!,
                        endDate: selectedEndDate,
                      );
                      context.read<SeasonBloc>().add(AddSeasonEvent(season));
                      Navigator.pop(context);
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Season Name *',
                            border: OutlineInputBorder(),
                          ),
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
                            final displayName = variety.isNotEmpty
                                ? '$name ($variety)'
                                : name;
                            return DropdownMenuItem<String>(
                              value: plant.id,
                              child: Text(displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedPlantId = value;
                            });
                          },
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
                            final displayName = location.isNotEmpty
                                ? '$name ($location)'
                                : name;
                            return DropdownMenuItem<String>(
                              value: land.id,
                              child: Text(displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLandId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Start Date *'),
                          subtitle: Text(
                            selectedStartDate != null
                                ? _formatDate(selectedStartDate!)
                                : 'Select start date',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  selectedStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() {
                                selectedStartDate = date;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('End Date (Optional)'),
                          subtitle: Text(
                            selectedEndDate != null &&
                                    selectedEndDate!.year > 2000
                                ? _formatDate(selectedEndDate!)
                                : 'Select end date (optional)',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectedEndDate != null &&
                                  selectedEndDate!.year > 2000)
                                IconButton(
                                  icon:
                                      const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      selectedEndDate = null;
                                    });
                                  },
                                ),
                              const Icon(Icons.calendar_today),
                            ],
                          ),
                          onTap: () async {
                            final validEndDate =
                                selectedEndDate != null &&
                                        selectedEndDate!.year > 2000
                                    ? selectedEndDate
                                    : null;
                            final initialDate = validEndDate ??
                                selectedStartDate ??
                                DateTime.now();
                            final firstDate =
                                selectedStartDate ?? DateTime(2020);

                            if (initialDate.isBefore(firstDate)) {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: firstDate,
                                firstDate: firstDate,
                                lastDate: DateTime(2030),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedEndDate = date;
                                });
                              }
                            } else {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate: firstDate,
                                lastDate: DateTime(2030),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedEndDate = date;
                                });
                              }
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
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Season name is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedPlantId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a plant'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedLandId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a land'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedStartDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a start date'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final updatedSeason = SeasonModel(
                        id: season.id,
                        userId: season.userId,
                        name: nameController.text.trim(),
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
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Season updated successfully'),
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

  void _showDeleteConfirmation(Season season) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Season',
      message:
          'Are you sure you want to delete "${season.name}"? This action cannot be undone.',
    );
    if (confirmed == true) {
      context.read<SeasonBloc>().add(DeleteSeasonEvent(season.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${season.name} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
