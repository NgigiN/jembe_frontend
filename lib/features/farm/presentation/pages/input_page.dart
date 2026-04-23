import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/input_bloc.dart';
import '../bloc/input_event.dart';
import '../bloc/input_state.dart';
import '../bloc/herd_bloc.dart';
import '../bloc/herd_event.dart';
import '../bloc/herd_state.dart';
import '../../domain/entities/input.dart';
import '../../domain/entities/herd.dart';
import '../../domain/entities/season.dart';
import '../bloc/cost_category_bloc.dart';
import '../bloc/cost_category_event.dart';
import '../bloc/cost_category_state.dart';
import '../bloc/season_bloc.dart';
import '../bloc/season_event.dart';
import '../bloc/season_state.dart';
import '../../domain/entities/cost_category.dart';
import '../../data/models/input_model.dart';

class InputPage extends StatefulWidget {
  final String? sourceType;

  const InputPage({super.key, this.sourceType});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  @override
  void initState() {
    super.initState();
    context.read<InputBloc>().add(GetInputsEvent(sourceType: widget.sourceType));
    context.read<HerdBloc>().add(GetHerdsEvent());
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<CostCategoryBloc>().add(
          GetCostCategoriesEvent(category: 'input'),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Management'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<InputBloc, InputState>(
        builder: (context, state) {
          if (state is InputLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InputError) {
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
                      context.read<InputBloc>().add(
                        GetInputsEvent(sourceType: widget.sourceType),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is InputLoaded) {
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first input',
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
    DateTime? selectedDate = DateTime.now();
    String? selectedSourceType = 'plant';
    String? selectedSeasonId;
    String? selectedHerdId;

    final seasonState = context.read<SeasonBloc>().state;
    final seasons = seasonState is SeasonLoaded ? seasonState.seasons : <Season>[];

    final costCategoryState = context.read<CostCategoryBloc>().state;
    final allCategories = costCategoryState is CostCategoryLoaded
        ? costCategoryState.categories
        : <CostCategory>[];

    final herdState = context.read<HerdBloc>().state;
    final herds = herdState is HerdLoaded ? herdState.herds : <Herd>[];

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
                      'Add New Input',
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
                          DropdownButtonFormField<String>(
                            initialValue: selectedSeasonId,
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
                          ),
                        if (selectedSourceType == 'animal')
                          DropdownButtonFormField<String>(
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
                                items: allCategories
                                    .where((c) => c.type == selectedSourceType)
                                    .map((category) {
                                  return DropdownMenuItem<String>(
                                    value: category.name,
                                    child: Text(category.name),
                                  );
                                }).toList(),
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
                          : selectedHerdId!;

                      final input = InputModel.create(
                        sourceType: selectedSourceType!,
                        sourceId: sourceId,
                        animalId: selectedSourceType == 'animal' ? 0 : null,
                        type: typeController.text.trim(),
                        quantity: double.tryParse(quantityController.text.trim()),
                        cost: cost,
                        date: selectedDate!,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      );
                      context.read<InputBloc>().add(AddInputEvent(input));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
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
    String? selectedHerdId = input.sourceType == 'animal'
        ? input.sourceId
        : null;

    final seasonState = context.read<SeasonBloc>().state;
    final seasons = seasonState is SeasonLoaded ? seasonState.seasons : <Season>[];

    final costCategoryState = context.read<CostCategoryBloc>().state;
    final allCategories = costCategoryState is CostCategoryLoaded
        ? costCategoryState.categories
        : <CostCategory>[];

    final herdState = context.read<HerdBloc>().state;
    final herds = herdState is HerdLoaded ? herdState.herds : <Herd>[];

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
                      'Edit Input',
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
                          DropdownButtonFormField<String>(
                            initialValue: selectedSeasonId,
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
                          ),
                        if (selectedSourceType == 'animal')
                          DropdownButtonFormField<String>(
                            initialValue: selectedHerdId,
                            decoration: const InputDecoration(
                              labelText: 'Select Herd *',
                              border: OutlineInputBorder(),
                            ),
                            items: herds.map<DropdownMenuItem<String>>((herd) {
                              return DropdownMenuItem<String>(
                                value: herd.id,
                                child: Text('${herd.name} (${herd.location})'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedHerdId = value;
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
                                initialValue: typeController.text.isEmpty
                                    ? null
                                    : typeController.text,
                                decoration: const InputDecoration(
                                  labelText: 'Input Type *',
                                  border: OutlineInputBorder(),
                                ),
                                items: allCategories
                                    .where((c) => c.type == selectedSourceType)
                                    .map((category) {
                                  return DropdownMenuItem<String>(
                                    value: category.name,
                                    child: Text(category.name),
                                  );
                                }).toList(),
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
                          : selectedHerdId!;

                      final updatedInput = InputModel(
                        id: input.id,
                        sourceType: selectedSourceType!,
                        sourceId: sourceId,
                        animalId: selectedSourceType == 'animal' ? 0 : null,
                        type: typeController.text.trim(),
                        quantity: double.tryParse(quantityController.text.trim()),
                        cost: cost,
                        date: selectedDate!,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                        createdAt: input.createdAt,
                        updatedAt: DateTime.now(),
                      );

                      context.read<InputBloc>().add(UpdateInputEvent(updatedInput));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Input updated successfully'),
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
                context.read<InputBloc>().add(DeleteInputEvent(input.id));
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

              context.read<CostCategoryBloc>().add(
                    AddCostCategoryEvent(
                      name: nameController.text.trim(),
                      type: sourceType,
                      category: 'input',
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
