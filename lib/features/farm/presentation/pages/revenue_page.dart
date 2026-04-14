import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/app_router.dart';
import '../bloc/revenue_bloc.dart';
import '../bloc/revenue_event.dart';
import '../bloc/revenue_state.dart';
import '../bloc/herd_bloc.dart';
import '../bloc/herd_event.dart';
import '../bloc/herd_state.dart';
import '../../domain/entities/revenue.dart';
import '../../data/services/farm_data_service.dart';

class RevenuePage extends StatelessWidget {
  const RevenuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue Management'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              Theme.of(context).colorScheme.surface
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(context.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Farm Revenue',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Track income from plant and animal operations',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              SizedBox(height: context.paddingLarge),
              Expanded(
                child: GridView.count(
                  crossAxisCount: context.screenWidth > 600 ? 3 : 2,
                  crossAxisSpacing: context.paddingMedium,
                  mainAxisSpacing: context.paddingMedium,
                  childAspectRatio: 0.85,
                  children: [
                    _buildRevenueCard(
                      context,
                      'All Revenue',
                      Icons.monetization_on,
                      Theme.of(context).colorScheme.primary,
                      () => _showAllRevenue(context),
                    ),
                    _buildRevenueCard(
                      context,
                      'Plant Revenue',
                      Icons.eco,
                      AppColors.plantCategory,
                      () => _showPlantRevenue(context),
                    ),
                    _buildRevenueCard(
                      context,
                      'Animal Revenue',
                      Icons.pets,
                      AppColors.animalCategory,
                      () => _showAnimalRevenue(context),
                    ),
                    _buildRevenueCard(
                      context,
                      'Add Revenue',
                      Icons.add_circle,
                      Theme.of(context).colorScheme.secondary,
                      () => _showAddRevenue(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(context.paddingMedium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: context.fontSize(40), color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to view',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllRevenue(BuildContext context) {
    context.read<RevenueBloc>().add(LoadRevenues());
    context.push(AppRoutePath.revenueAll);
  }

  void _showPlantRevenue(BuildContext context) {
    context.read<RevenueBloc>().add(LoadRevenues(source: 'plant'));
    context.push(AppRoutePath.revenueFilterFor('plant'));
  }

  void _showAnimalRevenue(BuildContext context) {
    context.read<RevenueBloc>().add(LoadRevenues(source: 'animal'));
    context.push(AppRoutePath.revenueFilterFor('animal'));
  }

  void _showAddRevenue(BuildContext context) {
    context.push(AppRoutePath.revenueAdd);
  }
}

class AllRevenuePage extends StatelessWidget {
  const AllRevenuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Revenue'),
      ),
      body: BlocConsumer<RevenueBloc, RevenueState>(
        listener: (context, state) {
          if (state is RevenueDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Revenue deleted successfully')),
            );
          }
        },
        builder: (context, state) {
          if (state is RevenueLoading && state.revenues.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is RevenueError && state.revenues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<RevenueBloc>().add(LoadRevenues());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final revenues = state.revenues;
          if (revenues.isEmpty) {
            return const Center(child: Text('No revenue records found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: revenues.length,
            itemBuilder: (context, index) {
              final revenue = revenues[index];
              return _buildRevenueCard(context, revenue);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push(AppRoutePath.revenueAdd);
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRevenueCard(BuildContext context, Revenue revenue) {
    final color = revenue.source == 'plant' ? Colors.blue : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            revenue.source == 'plant' ? Icons.eco : Icons.pets,
            color: color,
          ),
        ),
        title: Text(
          revenue.type,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quantity: ${revenue.quantity}'),
            Text('Date: ${revenue.date.toString().split(' ')[0]}'),
            if (revenue.notes != null && revenue.notes!.isNotEmpty)
              Text(
                'Notes: ${revenue.notes}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'KES ${revenue.total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            Text(
              '@${revenue.unitPrice.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        onTap: () {
          _showRevenueDetails(context, revenue);
        },
      ),
    );
  }

  void _showRevenueDetails(BuildContext context, Revenue revenue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RevenueDetailsSheet(revenue: revenue),
    );
  }
}

class FilteredRevenuePage extends StatelessWidget {
  final String source;

  const FilteredRevenuePage({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final title = source == 'plant' ? 'Plant Revenue' : 'Animal Revenue';
    final color = source == 'plant'
        ? Colors.blue.shade600
        : Colors.orange.shade600;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<RevenueBloc, RevenueState>(
        builder: (context, state) {
          if (state is RevenueLoading && state.revenues.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is RevenueError && state.revenues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final revenues = state.revenues;
          if (revenues.isEmpty) {
            return Center(child: Text('No $source revenue records found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: revenues.length,
            itemBuilder: (context, index) {
              final revenue = revenues[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    revenue.type,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quantity: ${revenue.quantity}'),
                      Text('Date: ${revenue.date.toString().split(' ')[0]}'),
                    ],
                  ),
                  trailing: Text(
                    'KES ${revenue.total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push(AppRoutePath.revenueAdd);
        },
        backgroundColor: color,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class RevenueDetailsSheet extends StatelessWidget {
  final Revenue revenue;

  const RevenueDetailsSheet({super.key, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    revenue.type,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text(revenue.source.toUpperCase()),
                    backgroundColor: revenue.source == 'plant'
                        ? Colors.blue.shade100
                        : Colors.orange.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Quantity', revenue.quantity.toString()),
              _buildDetailRow(
                'Unit Price',
                'KES ${revenue.unitPrice.toStringAsFixed(2)}',
              ),
              _buildDetailRow(
                'Total',
                'KES ${revenue.total.toStringAsFixed(2)}',
              ),
              _buildDetailRow('Date', revenue.date.toString().split(' ')[0]),
              if (revenue.notes != null && revenue.notes!.isNotEmpty)
                _buildDetailRow('Notes', revenue.notes!),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _confirmDelete(context, revenue.id);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Revenue'),
        content: const Text(
          'Are you sure you want to delete this revenue record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<RevenueBloc>().add(DeleteRevenueEvent(id));
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class AddRevenuePage extends StatefulWidget {
  final String? defaultSource;

  const AddRevenuePage({super.key, this.defaultSource});

  @override
  State<AddRevenuePage> createState() => _AddRevenuePageState();
}

class _AddRevenuePageState extends State<AddRevenuePage> {
  final _formKey = GlobalKey<FormState>();
  String _source = 'plant';
  String? _selectedSourceId;
  final _typeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _seasons = [];
  bool _isLoadingSeasons = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultSource != null) {
      _source = widget.defaultSource!;
    }
    context.read<HerdBloc>().add(GetHerdsEvent());
    _loadSeasons();
  }

  @override
  void dispose() {
    _typeController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSeasons() async {
    setState(() => _isLoadingSeasons = true);
    try {
      final seasons = await FarmDataService.getSeasonsForDropdown();
      setState(() {
        _seasons = seasons;
        _isLoadingSeasons = false;
      });
    } catch (e) {
      setState(() => _isLoadingSeasons = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Revenue'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      body: BlocListener<RevenueBloc, RevenueState>(
        listener: (context, state) {
          if (state is RevenueAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Revenue added successfully!')),
            );
            Navigator.pop(context);
            context.read<RevenueBloc>().add(LoadRevenues());
          } else if (state is RevenueError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: ${state.message}')));
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Revenue Source',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _source,
                          decoration: const InputDecoration(
                            labelText: 'Source',
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
                              _source = value!;
                              _selectedSourceId = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_source == 'plant')
                          _isLoadingSeasons
                              ? const Center(child: CircularProgressIndicator())
                              : DropdownButtonFormField<String>(
                                  initialValue: _selectedSourceId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Season *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _seasons
                                      .where(
                                        (season) =>
                                            season['id'] != null &&
                                            season['id'].toString().isNotEmpty,
                                      )
                                      .map((season) {
                                        final id =
                                            season['id']?.toString() ?? '';
                                        return DropdownMenuItem<String>(
                                          value: id,
                                          child: Text(
                                            season['name']?.toString() ?? '',
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSourceId = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a season';
                                    }
                                    return null;
                                  },
                                ),
                        if (_source == 'animal')
                          BlocBuilder<HerdBloc, HerdState>(
                            builder: (context, herdState) {
                              if (herdState is HerdLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (herdState is HerdLoaded) {
                                final herds = herdState.herds;
                                return DropdownButtonFormField<String>(
                                  initialValue: _selectedSourceId,
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
                                      _selectedSourceId = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a herd';
                                    }
                                    return null;
                                  },
                                );
                              }
                              return const Text('No herds available');
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Revenue Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _typeController,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            hintText: 'e.g., Maize Harvest, Milk, Cattle Sale',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter revenue type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter quantity';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _unitPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Unit Price',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter unit price';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date'),
                          subtitle: Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _selectedDate = date;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Revenue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _calculateTotal(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                BlocBuilder<RevenueBloc, RevenueState>(
                  builder: (context, state) {
                    return ElevatedButton(
                      onPressed: state is RevenueLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: state is RevenueLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Add Revenue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _calculateTotal() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;
    final total = quantity * unitPrice;
    return 'KES ${total.toStringAsFixed(2)}';
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedSourceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _source == 'plant'
                  ? 'Please select a season'
                  : 'Please select a herd',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final quantity = double.parse(_quantityController.text);
      final unitPrice = double.parse(_unitPriceController.text);

      context.read<RevenueBloc>().add(
        AddRevenueEvent(
          source: _source,
          sourceId: _selectedSourceId!,
          type: _typeController.text,
          quantity: quantity,
          unitPrice: unitPrice,
          date: _selectedDate,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        ),
      );
    }
  }
}
