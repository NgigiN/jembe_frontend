import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/season_bloc.dart';
import '../bloc/season_event.dart';
import '../bloc/season_state.dart';
import '../../domain/entities/season.dart';
import '../../data/models/season_model.dart';
import '../../data/services/farm_data_service.dart';
import '../../../auth/data/utils/user_utils.dart';

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
  }

  @override
  Widget build(BuildContext context) {
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
                      context.read<SeasonBloc>().add(GetSeasonsEvent());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is SeasonLoaded) {
            if (state.seasons.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No seasons registered yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first season',
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
              itemCount: state.seasons.length,
              itemBuilder: (context, index) {
                final season = state.seasons[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(
                        Icons.calendar_today,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    title: Text(
                      season.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Date: ${_formatDate(season.startDate)}'),
                        if (season.endDate != null)
                          Text('End Date: ${_formatDate(season.endDate!)}'),
                        Text(
                          'Created: ${_formatDate(season.createdAt)}',
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
                          _showEditSeasonDialog(context, season);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context, season);
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
        onPressed: () => _showAddSeasonDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddSeasonDialog(BuildContext context) async {
    final nameController = TextEditingController();
    DateTime? selectedStartDate;
    DateTime? selectedEndDate;
    String? selectedPlantId;
    String? selectedLandId;

    // Fetch lands and plants for dropdowns
    final lands = await FarmDataService.getLandsForDropdown();
    final plants = await FarmDataService.getPlantsForDropdown();

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                          items: plants
                              .where(
                                (plant) =>
                                    (plant['id']?.toString() ?? '').isNotEmpty,
                              )
                              .map((plant) {
                                final name = (plant['name'] ?? '').toString();
                                final variety = (plant['variety'] ?? '')
                                    .toString();
                                final displayName = variety.isNotEmpty
                                    ? '$name ($variety)'
                                    : name;
                                return DropdownMenuItem<String>(
                                  value: plant['id']?.toString() ?? '',
                                  child: Text(displayName),
                                );
                              })
                              .toList(),
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
                          items: lands
                              .where(
                                (land) =>
                                    (land['id']?.toString() ?? '').isNotEmpty,
                              )
                              .map((land) {
                                final name = (land['name'] ?? '').toString();
                                final location = (land['location'] ?? '')
                                    .toString();
                                final displayName = location.isNotEmpty
                                    ? '$name ($location)'
                                    : name;
                                return DropdownMenuItem<String>(
                                  value: land['id']?.toString() ?? '',
                                  child: Text(displayName),
                                );
                              })
                              .toList(),
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
                              initialDate: selectedStartDate ?? DateTime.now(),
                              firstDate: selectedStartDate ?? DateTime(2020),
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

  void _showEditSeasonDialog(BuildContext context, Season season) async {
    final nameController = TextEditingController(text: season.name);
    DateTime? selectedStartDate = season.startDate;
    DateTime? selectedEndDate =
        season.endDate != null && season.endDate!.year > 2000
        ? season.endDate
        : null;
    String? selectedPlantId = season.plantId;
    String? selectedLandId = season.landId;

    // Fetch lands and crops for dropdowns
    final lands = await FarmDataService.getLandsForDropdown();
    final plants = await FarmDataService.getPlantsForDropdown();

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                          items: plants
                              .where(
                                (plant) =>
                                    (plant['id']?.toString() ?? '').isNotEmpty,
                              )
                              .map((plant) {
                                final name = (plant['name'] ?? '').toString();
                                final variety = (plant['variety'] ?? '')
                                    .toString();
                                final displayName = variety.isNotEmpty
                                    ? '$name ($variety)'
                                    : name;
                                return DropdownMenuItem<String>(
                                  value: plant['id']?.toString() ?? '',
                                  child: Text(displayName),
                                );
                              })
                              .toList(),
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
                          items: lands
                              .where(
                                (land) =>
                                    (land['id']?.toString() ?? '').isNotEmpty,
                              )
                              .map((land) {
                                final name = (land['name'] ?? '').toString();
                                final location = (land['location'] ?? '')
                                    .toString();
                                final displayName = location.isNotEmpty
                                    ? '$name ($location)'
                                    : name;
                                return DropdownMenuItem<String>(
                                  value: land['id']?.toString() ?? '',
                                  child: Text(displayName),
                                );
                              })
                              .toList(),
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
                              initialDate: selectedStartDate ?? DateTime.now(),
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
                                  icon: const Icon(Icons.clear, size: 20),
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
                            final initialDate =
                                validEndDate ??
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

  void _showDeleteConfirmation(BuildContext context, Season season) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Season'),
          content: Text(
            'Are you sure you want to delete "${season.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<SeasonBloc>().add(DeleteSeasonEvent(season.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${season.name} deleted successfully'),
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
}
