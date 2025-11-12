import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/farm_bloc.dart';
import '../bloc/farm_event.dart';
import '../bloc/farm_state.dart';
import '../../domain/entities/season.dart';
// Removed unused import
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
    context.read<FarmBloc>().add(GetSeasonsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Season Management'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<FarmBloc, FarmState>(
        builder: (context, state) {
          if (state is FarmLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is FarmError) {
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
                      context.read<FarmBloc>().add(GetSeasonsEvent());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is FarmLoaded) {
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
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first season',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
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
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
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
    String? selectedPlantName;
    String? selectedLandName;

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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Season',
                      style: TextStyle(
                        fontSize: 20,
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
                          items: plants.map((plant) {
                            final name = plant['name'] ?? '';
                            final variety = plant['variety'] ?? '';
                            final displayName = variety.isNotEmpty
                                ? '$name ($variety)'
                                : name;
                            return DropdownMenuItem<String>(
                              value: plant['id']?.toString() ?? '',
                              child: Text(displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedPlantId = value;
                              selectedPlantName =
                                  plants.firstWhere(
                                    (p) => p['id'] == value,
                                  )['name'] ??
                                  '';
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
                            final name = land['name'] ?? '';
                            final location = land['location'] ?? '';
                            final displayName = location.isNotEmpty
                                ? '$name ($location)'
                                : name;
                            return DropdownMenuItem<String>(
                              value: land['id']?.toString() ?? '',
                              child: Text(displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLandId = value;
                              selectedLandName =
                                  lands.firstWhere(
                                    (l) => l['id'] == value,
                                  )['name'] ??
                                  '';
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

                      // Removed unused variable

                      context.read<FarmBloc>().add(
                        AddSeasonEvent(
                          nameController.text.trim(),
                          selectedLandId!,
                          selectedPlantId!,
                          selectedStartDate!.toIso8601String(),
                          selectedEndDate?.toIso8601String() ?? '',
                          userId,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
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
    DateTime? selectedEndDate = season.endDate;
    String? selectedPlantId = season.plantId;
    String? selectedLandId = season.landId;
    String? selectedPlantName;
    String? selectedLandName;

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

    // Set initial values for display
    selectedPlantName =
        plants.firstWhere(
          (p) => p['id'] == selectedPlantId,
          orElse: () => {'name': ''},
        )['name'] ??
        '';
    selectedLandName =
        lands.firstWhere(
          (l) => l['id'] == selectedLandId,
          orElse: () => {'name': ''},
        )['name'] ??
        '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Season',
                      style: TextStyle(
                        fontSize: 20,
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
                          items: plants.map((plant) {
                            final name = plant['name'] ?? '';
                            final variety = plant['variety'] ?? '';
                            final displayName = variety.isNotEmpty
                                ? '$name ($variety)'
                                : name;
                            return DropdownMenuItem<String>(
                              value: plant['id']?.toString() ?? '',
                              child: Text(displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedPlantId = value;
                              selectedPlantName =
                                  plants.firstWhere(
                                    (p) => p['id'] == value,
                                  )['name'] ??
                                  '';
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
                            final name = land['name'] ?? '';
                            final location = land['location'] ?? '';
                            final displayName = location.isNotEmpty
                                ? '$name ($location)'
                                : name;
                            return DropdownMenuItem<String>(
                              value: land['id']?.toString() ?? '',
                              child: Text(displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLandId = value;
                              selectedLandName =
                                  lands.firstWhere(
                                    (l) => l['id'] == value,
                                  )['name'] ??
                                  '';
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
                            selectedEndDate != null
                                ? _formatDate(selectedEndDate!)
                                : 'Select end date (optional)',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  selectedEndDate ??
                                  selectedStartDate ??
                                  DateTime.now(),
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

                      context.read<FarmBloc>().add(
                        UpdateSeasonEvent(
                          season.id,
                          nameController.text.trim(),
                          selectedLandId!,
                          selectedPlantId!,
                          selectedStartDate!.toIso8601String(),
                          selectedEndDate?.toIso8601String() ?? '',
                        ),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
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
                context.read<FarmBloc>().add(DeleteSeasonEvent(season.id));
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
