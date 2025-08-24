import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/farm_bloc.dart';
import '../bloc/farm_event.dart';
import '../bloc/farm_state.dart';
import '../../domain/entities/input.dart';
// Removed unused import
import '../../data/services/farm_data_service.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  @override
  void initState() {
    super.initState();
    context.read<FarmBloc>().add(GetInputsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Management'),
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
                      context.read<FarmBloc>().add(GetInputsEvent());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is FarmLoaded) {
            final inputs = state.inputs;
            if (inputs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.input, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No inputs registered yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first input',
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
              itemCount: state.inputs.length,
              itemBuilder: (context, index) {
                final input = state.inputs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade100,
                      child: Icon(Icons.input, color: Colors.purple.shade700),
                    ),
                    title: Text(
                      input.type,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cost: \$${input.cost.toStringAsFixed(2)}'),
                        if (input.quantity != null)
                          Text('Quantity: ${input.quantity}'),
                        Text('Date: ${_formatDate(input.date)}'),
                        if (input.notes != null && input.notes!.isNotEmpty)
                          Text('Notes: ${input.notes}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditInputDialog(context, input);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context, input);
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
        onPressed: () => _showAddInputDialog(context),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddInputDialog(BuildContext context) async {
    final typeController = TextEditingController();
    final quantityController = TextEditingController();
    final costController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? selectedDate;
    String? selectedSeasonId;
    String? selectedSeasonName;

    // Predefined input types based on PocketBase schema
    final inputTypes = [
      'Seeds',
      'Nursery',
      'Water',
      'Labor',
      'Transport',
      'Miscellaneous',
      'Fertilizer',
      'Salaries',
      'Milling',
      'Sacks',
      'Storage',
      'Other',
    ];

    // Fetch seasons for dropdown
    final seasons = await FarmDataService.getSeasonsForDropdown();

    if (seasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one season first'),
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
                      'Add New Input',
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
                        DropdownButtonFormField<String>(
                          value: selectedSeasonId,
                          decoration: const InputDecoration(
                            labelText: 'Select Season *',
                            border: OutlineInputBorder(),
                          ),
                          items: seasons.map((season) {
                            return DropdownMenuItem<String>(
                              value: season['id'] as String,
                              child: Text(season['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSeasonId = value;
                              selectedSeasonName = seasons.firstWhere(
                                (s) => s['id'] == value,
                              )['name'];
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Input Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: inputTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              typeController.text = value ?? '';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: costController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cost *',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
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
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
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
                      if (selectedSeasonId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a season'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (typeController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select an input type'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (costController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a cost'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final cost = double.tryParse(costController.text.trim());
                      if (cost == null || cost <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid cost'),
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

                      // Removed unused variable

                      context.read<FarmBloc>().add(
                        AddInputEvent(
                          selectedSeasonId!,
                          typeController.text.trim(),
                          double.tryParse(quantityController.text.trim()),
                          cost,
                          selectedDate!.toIso8601String(),
                          notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
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
                      'Add Input',
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

  void _showEditInputDialog(BuildContext context, Input input) async {
    final typeController = TextEditingController(text: input.type);
    final quantityController = TextEditingController(
      text: input.quantity?.toString() ?? '',
    );
    final costController = TextEditingController(text: input.cost.toString());
    final notesController = TextEditingController(text: input.notes ?? '');
    DateTime? selectedDate = input.date;
    String? selectedSeasonId = input.seasonId;
    String? selectedSeasonName;

    // Predefined input types based on PocketBase schema
    final inputTypes = [
      'Seeds',
      'Fertilizer',
      'Pesticides',
      'Herbicides',
      'Tools',
      'Equipment',
      'Fuel',
      'Nursery',
      'Water',
      'Labor',
      'Transport',
      'Miscellaneous',
      'Fertilizer',
      'Salaries',
      'Milling',
      'Sacks',
      'Storage',
      'Other',
    ];

    // Fetch seasons for dropdown
    final seasons = await FarmDataService.getSeasonsForDropdown();

    if (seasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No seasons available for editing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Set initial values for display
    selectedSeasonName = seasons.firstWhere(
      (s) => s['id'] == selectedSeasonId,
    )['name'];

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
                      'Edit Input',
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
                        DropdownButtonFormField<String>(
                          value: selectedSeasonId,
                          decoration: const InputDecoration(
                            labelText: 'Select Season *',
                            border: OutlineInputBorder(),
                          ),
                          items: seasons.map((season) {
                            return DropdownMenuItem<String>(
                              value: season['id'] as String,
                              child: Text(season['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSeasonId = value;
                              selectedSeasonName = seasons.firstWhere(
                                (s) => s['id'] == value,
                              )['name'];
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: typeController.text,
                          decoration: const InputDecoration(
                            labelText: 'Input Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: inputTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              typeController.text = value ?? '';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity (Optional)',
                            border: OutlineInputBorder(),
                            hintText: 'Enter quantity',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: costController,
                          decoration: const InputDecoration(
                            labelText: 'Cost *',
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
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
                        const SizedBox(height: 16),
                        TextField(
                          controller: notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                            hintText: 'Enter additional notes',
                          ),
                          maxLines: 3,
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
                      if (selectedSeasonId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a season'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (typeController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select an input type'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (costController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a cost'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final cost = double.tryParse(costController.text.trim());
                      if (cost == null || cost <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid cost'),
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

                      context.read<FarmBloc>().add(
                        UpdateInputEvent(
                          input.id,
                          selectedSeasonId!,
                          typeController.text.trim(),
                          double.tryParse(quantityController.text.trim()),
                          cost,
                          selectedDate!.toIso8601String(),
                          notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
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
                      'Update Input',
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

  void _showDeleteConfirmation(BuildContext context, Input input) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Input'),
          content: Text(
            'Are you sure you want to delete this ${input.type.toLowerCase()} input? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<FarmBloc>().add(DeleteInputEvent(input.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${input.type} input deleted successfully'),
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
