import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/farm_bloc.dart';
import '../bloc/farm_event.dart';
import '../bloc/farm_state.dart';
import '../../domain/entities/input.dart';
import '../../data/services/farm_data_service.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  List<Map<String, dynamic>> _plantInputTypes = [];
  List<Map<String, dynamic>> _animalInputTypes = [];

  @override
  void initState() {
    super.initState();
    context.read<FarmBloc>().add(GetInputsEvent());
    _loadCostCategories();
  }

  Future<void> _loadCostCategories() async {
    try {
      final plantInputs = await FarmDataService.getCostCategories(
        type: 'plant',
        category: 'input',
      );
      final animalInputs = await FarmDataService.getCostCategories(
        type: 'animal',
        category: 'input',
      );
      setState(() {
        _plantInputTypes = plantInputs;
        _animalInputTypes = animalInputs;
      });
    } catch (e) {
      // Silently handle errors
    }
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
                        Text('Cost: Ksh ${input.cost.toStringAsFixed(2)}'),
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
    String? selectedSourceType = 'plant';
    String? selectedSeasonId;
    String? selectedAnimalId;
    int? selectedAnimalIdInt;

    await _loadCostCategories();

    final seasons = await FarmDataService.getSeasonsForDropdown();
    final animals = await FarmDataService.getAnimalsForDropdown();

    if (seasons.isEmpty && animals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one season or animal first'),
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
                          value: selectedSourceType,
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
                              selectedAnimalId = null;
                              selectedAnimalIdInt = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (selectedSourceType == 'plant')
                          DropdownButtonFormField<String>(
                            value: selectedSeasonId,
                            decoration: const InputDecoration(
                              labelText: 'Select Season *',
                              border: OutlineInputBorder(),
                            ),
                            items: seasons
                                .where((season) =>
                                    season['id'] != null &&
                                    season['id'].toString().isNotEmpty)
                                .fold<Map<String, Map<String, dynamic>>>(
                                  {},
                                  (map, season) {
                                    final id = season['id']?.toString() ?? '';
                                    if (id.isNotEmpty && !map.containsKey(id)) {
                                      map[id] = season;
                                    }
                                    return map;
                                  },
                                )
                                .values
                                .map((season) {
                                  final id = season['id']?.toString() ?? '';
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(season['name']?.toString() ?? ''),
                                  );
                                })
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSeasonId = value;
                              });
                            },
                          ),
                        if (selectedSourceType == 'animal')
                          DropdownButtonFormField<String>(
                            value: selectedAnimalId,
                            decoration: const InputDecoration(
                              labelText: 'Select Animal *',
                              border: OutlineInputBorder(),
                            ),
                            items: animals
                                .where((animal) =>
                                    animal['id'] != null &&
                                    animal['id'].toString().isNotEmpty)
                                .fold<Map<String, Map<String, dynamic>>>(
                                  {},
                                  (map, animal) {
                                    final id = animal['id']?.toString() ?? '';
                                    if (id.isNotEmpty && !map.containsKey(id)) {
                                      map[id] = animal;
                                    }
                                    return map;
                                  },
                                )
                                .values
                                .map((animal) {
                                  final id = animal['id']?.toString() ?? '';
                                  final displayName =
                                      animal['type'] != null &&
                                          animal['type'].toString().isNotEmpty
                                      ? '${animal['name']} (${animal['type']})'
                                      : animal['name']?.toString() ?? '';
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(displayName),
                                  );
                                })
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedAnimalId = value;
                                selectedAnimalIdInt = value != null
                                    ? int.tryParse(value)
                                    : null;
                              });
                            },
                          ),
                        if (selectedSourceType == 'plant' ||
                            selectedSourceType == 'animal')
                          const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Input Type *',
                                  border: OutlineInputBorder(),
                                ),
                                items:
                                    (selectedSourceType == 'plant'
                                            ? _plantInputTypes
                                            : _animalInputTypes)
                                        .where((category) =>
                                            category['name'] != null &&
                                            category['name'].toString().isNotEmpty)
                                        .map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category['name']?.toString() ?? '',
                                            child: Text(
                                              category['name']?.toString() ?? '',
                                            ),
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
                              onPressed: () => _showCreateInputTypeDialog(
                                context,
                                selectedSourceType!,
                                () => _loadCostCategories(),
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Add new input type',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                              ),
                            ),
                          ],
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
                            prefixText: 'Ksh ',
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
                          selectedAnimalId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select an animal'),
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

                      final sourceId = selectedSourceType == 'plant'
                          ? selectedSeasonId!
                          : selectedAnimalId!;

                      context.read<FarmBloc>().add(
                        AddInputEvent(
                          selectedSourceType!,
                          sourceId,
                          selectedAnimalIdInt,
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
    String? selectedSourceType = input.sourceType;
    String? selectedSeasonId = input.sourceType == 'plant'
        ? input.sourceId
        : null;
    String? selectedAnimalId = input.sourceType == 'animal'
        ? input.sourceId
        : null;
    int? selectedAnimalIdInt = input.animalId;

    await _loadCostCategories();

    final seasons = await FarmDataService.getSeasonsForDropdown();
    final animals = await FarmDataService.getAnimalsForDropdown();

    if ((selectedSourceType == 'plant' && seasons.isEmpty) ||
        (selectedSourceType == 'animal' && animals.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No seasons or animals available for editing'),
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
                          value: selectedSourceType,
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
                                selectedAnimalId = null;
                                selectedAnimalIdInt = null;
                              } else {
                                selectedSeasonId = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (selectedSourceType == 'plant')
                          DropdownButtonFormField<String>(
                            value: selectedSeasonId != null &&
                                    selectedSeasonId.toString().isNotEmpty
                                ? selectedSeasonId.toString()
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Select Season *',
                              border: OutlineInputBorder(),
                            ),
                            items: seasons
                                .where((season) =>
                                    season['id'] != null &&
                                    season['id'].toString().isNotEmpty)
                                .fold<Map<String, Map<String, dynamic>>>(
                                  {},
                                  (map, season) {
                                    final id = season['id']?.toString() ?? '';
                                    if (id.isNotEmpty && !map.containsKey(id)) {
                                      map[id] = season;
                                    }
                                    return map;
                                  },
                                )
                                .values
                                .map((season) {
                                  final id = season['id']?.toString() ?? '';
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(season['name']?.toString() ?? ''),
                                  );
                                })
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSeasonId = value;
                              });
                            },
                          ),
                        if (selectedSourceType == 'animal')
                          DropdownButtonFormField<String>(
                            value: selectedAnimalId != null &&
                                    selectedAnimalId.toString().isNotEmpty
                                ? selectedAnimalId.toString()
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Select Animal *',
                              border: OutlineInputBorder(),
                            ),
                            items: animals
                                .where((animal) =>
                                    animal['id'] != null &&
                                    animal['id'].toString().isNotEmpty)
                                .fold<Map<String, Map<String, dynamic>>>(
                                  {},
                                  (map, animal) {
                                    final id = animal['id']?.toString() ?? '';
                                    if (id.isNotEmpty && !map.containsKey(id)) {
                                      map[id] = animal;
                                    }
                                    return map;
                                  },
                                )
                                .values
                                .map((animal) {
                                  final id = animal['id']?.toString() ?? '';
                                  final displayName =
                                      animal['type'] != null &&
                                          animal['type'].toString().isNotEmpty
                                      ? '${animal['name']} (${animal['type']})'
                                      : animal['name']?.toString() ?? '';
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(displayName),
                                  );
                                })
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedAnimalId = value;
                                selectedAnimalIdInt = value != null
                                    ? int.tryParse(value)
                                    : null;
                              });
                            },
                          ),
                        if (selectedSourceType == 'plant' ||
                            selectedSourceType == 'animal')
                          const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: typeController.text.isEmpty
                                    ? null
                                    : typeController.text,
                                decoration: const InputDecoration(
                                  labelText: 'Input Type *',
                                  border: OutlineInputBorder(),
                                ),
                                items:
                                    (selectedSourceType == 'plant'
                                            ? _plantInputTypes
                                            : _animalInputTypes)
                                        .where((category) =>
                                            category['name'] != null &&
                                            category['name'].toString().isNotEmpty)
                                        .map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category['name']?.toString() ?? '',
                                            child: Text(
                                              category['name']?.toString() ?? '',
                                            ),
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
                              onPressed: () => _showCreateInputTypeDialog(
                                context,
                                selectedSourceType!,
                                () => _loadCostCategories(),
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Add new input type',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                              ),
                            ),
                          ],
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
                          selectedAnimalId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select an animal'),
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

                      final sourceId = selectedSourceType == 'plant'
                          ? selectedSeasonId!
                          : selectedAnimalId!;

                      context.read<FarmBloc>().add(
                        UpdateInputEvent(
                          input.id,
                          selectedSourceType!,
                          sourceId,
                          selectedAnimalIdInt,
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

  void _showCreateInputTypeDialog(
    BuildContext context,
    String sourceType,
    VoidCallback onCreated,
  ) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New ${sourceType == 'plant' ? 'Plant' : 'Animal'} Input Type',
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Input Type Name',
            hintText: 'e.g., Custom Fertilizer',
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

              final success = await FarmDataService.createCostCategory(
                name: nameController.text.trim(),
                type: sourceType,
                category: 'input',
              );

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${nameController.text.trim()} added successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                  onCreated();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to add input type'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
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
