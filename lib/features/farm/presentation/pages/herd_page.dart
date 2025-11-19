import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/farm_bloc.dart';
import '../bloc/farm_event.dart';
import '../bloc/farm_state.dart';
import '../../domain/entities/animal.dart';
import '../../../auth/data/utils/user_utils.dart';

class HerdPage extends StatefulWidget {
  const HerdPage({super.key});

  @override
  State<HerdPage> createState() => _HerdPageState();
}

class _HerdPageState extends State<HerdPage> {
  static const List<String> animalTypes = [
    'Broilers',
    'Rabbits',
    'Goats',
    'Beef Cows',
    'Milk Cows',
    'Chickens',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    context.read<FarmBloc>().add(GetAnimalsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Herd Management'),
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
                      context.read<FarmBloc>().add(GetAnimalsEvent());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is FarmLoaded) {
            if (state.animals.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No herds registered yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to register your first herd',
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
              itemCount: state.animals.length,
              itemBuilder: (context, index) {
                final animal = state.animals[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(Icons.pets, color: Colors.orange.shade700),
                    ),
                    title: Text(
                      animal.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type: ${animal.type}'),
                        if (animal.number != null)
                          Text('Number: ${animal.number}'),
                        Text(
                          'Created: ${_formatDate(animal.createdAt)}',
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
                          _showEditHerdDialog(context, animal);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context, animal);
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
        onPressed: () => _showAddHerdDialog(context),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddHerdDialog(BuildContext context) {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    String? selectedType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                      'Register New Herd',
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
                            labelText: 'Herd Name *',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., Main Chicken Coop',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Animal Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: animalTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: numberController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Number of Animals (Optional)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 50',
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
                            content: Text('Herd name is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Animal type is required'),
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

                      final number = numberController.text.trim().isEmpty
                          ? null
                          : int.tryParse(numberController.text.trim());

                      context.read<FarmBloc>().add(
                        AddAnimalEvent(
                          nameController.text.trim(),
                          selectedType!,
                          number,
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
                      'Register Herd',
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

  void _showEditHerdDialog(BuildContext context, Animal animal) {
    final nameController = TextEditingController(text: animal.name);
    final numberController = TextEditingController(
      text: animal.number?.toString() ?? '',
    );
    String? selectedType = animal.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                      'Edit Herd',
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
                            labelText: 'Herd Name *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Animal Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: animalTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: numberController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Number of Animals (Optional)',
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
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Herd name is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Animal type is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final number = numberController.text.trim().isEmpty
                          ? null
                          : int.tryParse(numberController.text.trim());

                      context.read<FarmBloc>().add(
                        UpdateAnimalEvent(
                          animal.id,
                          nameController.text.trim(),
                          selectedType!,
                          number,
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
                      'Update Herd',
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

  void _showDeleteConfirmation(BuildContext context, Animal animal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Herd'),
          content: Text(
            'Are you sure you want to delete "${animal.name}" (${animal.type})? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<FarmBloc>().add(DeleteAnimalEvent(animal.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${animal.name} deleted successfully'),
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
