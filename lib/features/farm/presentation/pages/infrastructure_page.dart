import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';

class InfrastructurePage extends StatefulWidget {
  const InfrastructurePage({super.key});

  @override
  State<InfrastructurePage> createState() => _InfrastructurePageState();
}

class _InfrastructurePageState extends State<InfrastructurePage> {
  final List<String> _infrastructureTypes = ['Store', 'House', 'Fence', 'Barn', 'Greenhouse', 'Other'];

  @override
  void initState() {
    super.initState();
    context.read<InfrastructureBloc>().add(GetInfrastructuresEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infrastructure Management'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<InfrastructureBloc, InfrastructureState>(
        builder: (context, state) {
          if (state is InfrastructureLoading && state.infrastructures.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InfrastructureError && state.infrastructures.isEmpty) {
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
                      context.read<InfrastructureBloc>().add(GetInfrastructuresEvent());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final list = state.infrastructures;

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.foundation,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No infrastructure registered yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add your first infrastructure item',
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
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      _getIconForType(item.type),
                      color: Colors.blue.shade700,
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type: ${item.type}'),
                      if (item.location.isNotEmpty) Text('Location: ${item.location}'),
                      Text('Cost: KES ${item.cost.toStringAsFixed(2)}'),
                      Text('Date: ${_formatDate(item.date)}'),
                      if (item.notes.isNotEmpty)
                        Text(
                          'Notes: ${item.notes}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddOrEditDialog(context, item: item);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(context, item);
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
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'store':
        return Icons.store;
      case 'house':
        return Icons.home;
      case 'fence':
        return Icons.fence;
      case 'barn':
        return Icons.roofing;
      case 'greenhouse':
        return Icons.opacity;
      default:
        return Icons.foundation;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddOrEditDialog(BuildContext context, {Infrastructure? item}) {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final locationController = TextEditingController(text: item?.location ?? '');
    final costController = TextEditingController(text: item?.cost.toString() ?? '');
    final notesController = TextEditingController(text: item?.notes ?? '');
    String selectedType = item != null && _infrastructureTypes.contains(item.type)
        ? item.type
        : _infrastructureTypes.first;
    DateTime selectedDate = item?.date ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Infrastructure' : 'Add New Infrastructure',
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
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Infrastructure Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: _infrastructureTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Infrastructure Name *',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., Main Barn, North Fence',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location *',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., North Field',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: costController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cost (KES) *',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 5000.00',
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.grey),
                                const SizedBox(width: 12),
                                Text(
                                  'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                            hintText: 'Optional notes or descriptions',
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
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Infrastructure name is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (locationController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final cost = double.tryParse(costController.text.trim());
                      if (cost == null || cost < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cost must be a positive number'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (isEditing) {
                        context.read<InfrastructureBloc>().add(
                              UpdateInfrastructureEvent(
                                id: item.id,
                                type: selectedType,
                                name: nameController.text.trim(),
                                location: locationController.text.trim(),
                                cost: cost,
                                date: selectedDate,
                                notes: notesController.text.trim(),
                              ),
                            );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Infrastructure updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
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

                        context.read<InfrastructureBloc>().add(
                              AddInfrastructureEvent(
                                type: selectedType,
                                name: nameController.text.trim(),
                                location: locationController.text.trim(),
                                cost: cost,
                                date: selectedDate,
                                userId: userId,
                                notes: notesController.text.trim(),
                              ),
                            );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Infrastructure added successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isEditing ? 'Update Infrastructure' : 'Add Infrastructure',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  void _showDeleteConfirmation(BuildContext context, Infrastructure item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Infrastructure'),
          content: Text(
            'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<InfrastructureBloc>().add(DeleteInfrastructureEvent(item.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.name} deleted successfully'),
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
