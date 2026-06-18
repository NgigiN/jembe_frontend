import 'package:flutter/material.dart';
import 'package:farm_tracker/core/utils/responsive_utils.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';

class RevenuePage extends StatefulWidget {
  const RevenuePage({super.key});

  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  String? _selectedSource; // null for All, 'plant', 'animal'

  @override
  void initState() {
    super.initState();
    _loadRevenues();
  }

  void _loadRevenues() {
    context.read<RevenueBloc>().add(LoadRevenues(source: _selectedSource));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue'),
        actions: [
          IconButton(
            onPressed: _loadRevenues,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
              Theme.of(context).colorScheme.surface
            ],
          ),
        ),
        child: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: BlocConsumer<RevenueBloc, RevenueState>(
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
                    return _buildErrorView(state.message);
                  }

                  final revenues = state.revenues;
                  if (revenues.isEmpty) {
                    return _buildEmptyView();
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: context.paddingMedium),
                    itemCount: revenues.length,
                    itemBuilder: (context, index) {
                      final revenue = revenues[index];
                      return _buildRevenueListItem(context, revenue);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutePath.revenueAdd),
        label: const Text('Add Revenue'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: EdgeInsets.all(context.paddingMedium),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFilterChip('All', null),
          const SizedBox(width: 8),
          _buildFilterChip('Plants', 'plant'),
          const SizedBox(width: 8),
          _buildFilterChip('Animals', 'animal'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedSource == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedSource = value;
          });
          _loadRevenues();
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRevenueListItem(BuildContext context, Revenue revenue) {
    final isPlant = revenue.source == 'plant';
    final color = isPlant ? AppColors.plantCategory : AppColors.animalCategory;
    final icon = isPlant ? Icons.eco : Icons.pets;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => _showRevenueDetails(context, revenue),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(context.paddingMedium),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      revenue.type,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Qty: ${revenue.quantity} | ${revenue.date.toString().split(' ')[0]}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KES ${revenue.total.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  Text(
                    '@${revenue.unitPrice.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadRevenues, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No revenue records found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (_selectedSource != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedSource = null;
                });
                _loadRevenues();
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  void _showRevenueDetails(BuildContext context, Revenue revenue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RevenueDetailsSheet(revenue: revenue),
    );
  }
}

class RevenueDetailsSheet extends StatelessWidget {

  const RevenueDetailsSheet({super.key, required this.revenue});
  final Revenue revenue;

  @override
  Widget build(BuildContext context) {
    final isPlant = revenue.source == 'plant';
    final color = isPlant ? AppColors.plantCategory : AppColors.animalCategory;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  revenue.type,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  revenue.source.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailItem(context, 'Quantity', revenue.quantity.toString()),
          _buildDetailItem(
            context,
            'Unit Price',
            'KES ${revenue.unitPrice.toStringAsFixed(2)}',
          ),
          _buildDetailItem(
            context,
            'Total Amount',
            'KES ${revenue.total.toStringAsFixed(2)}',
            isPrimary: true,
          ),
          _buildDetailItem(
            context,
            'Date',
            revenue.date.toString().split(' ')[0],
          ),
          if (revenue.notes != null && revenue.notes!.isNotEmpty)
            _buildDetailItem(context, 'Notes', revenue.notes!),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Add edit logic if needed later
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _confirmDelete(context, revenue.id),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value, {
    bool isPrimary = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                  color: isPrimary ? Theme.of(context).colorScheme.primary : null,
                  fontSize: isPrimary ? 18 : null,
                ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Revenue'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<RevenueBloc>().add(DeleteRevenueEvent(id));
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class AddRevenuePage extends StatefulWidget {

  const AddRevenuePage({super.key, this.defaultSource});
  final String? defaultSource;

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

  @override
  void initState() {
    super.initState();
    if (widget.defaultSource != null) {
      _source = widget.defaultSource!;
    }
    context.read<HerdBloc>().add(GetHerdsEvent());
    context.read<SeasonBloc>().add(GetSeasonsEvent());
  }

  @override
  void dispose() {
    _typeController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Revenue'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.message}')),
            );
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.paddingMedium),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Source',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _source,
                          decoration: const InputDecoration(
                            labelText: 'Select Category',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'plant', child: Text('Plant')),
                            DropdownMenuItem(value: 'animal', child: Text('Animal')),
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
                          BlocBuilder<SeasonBloc, SeasonState>(
                            builder: (context, state) {
                              if (state is SeasonLoading) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (state is SeasonLoaded) {
                                return DropdownButtonFormField<String>(
                                  initialValue: _selectedSourceId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Season',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: state.seasons.map((s) {
                                    return DropdownMenuItem(value: s.id, child: Text(s.name));
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedSourceId = v),
                                  validator: (v) => v == null ? 'Please select a season' : null,
                                );
                              }
                              return const Text('No seasons found');
                            },
                          ),
                        if (_source == 'animal')
                          BlocBuilder<HerdBloc, HerdState>(
                            builder: (context, state) {
                              if (state is HerdLoading) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (state is HerdLoaded) {
                                return DropdownButtonFormField<String>(
                                  initialValue: _selectedSourceId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Herd',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: state.herds.map((h) {
                                    return DropdownMenuItem(
                                      value: h.id,
                                      child: Text('${h.name} (${h.location})'),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedSourceId = v),
                                  validator: (v) => v == null ? 'Please select a herd' : null,
                                );
                              }
                              return const Text('No herds found');
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Details',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _typeController,
                          decoration: const InputDecoration(
                            labelText: 'Revenue Type',
                            hintText: 'e.g., Milk Sale, Maize Harvest',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) => (v == null || double.tryParse(v) == null)
                                    ? 'Invalid'
                                    : null,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _unitPriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Unit Price',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) => (v == null || double.tryParse(v) == null)
                                    ? 'Invalid'
                                    : null,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date'),
                          subtitle: Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          ),
                          trailing: const Icon(Icons.calendar_today_outlined),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) setState(() => _selectedDate = date);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated Total:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _calculateTotal(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _submitForm,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Revenue', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _calculateTotal() {
    final q = double.tryParse(_quantityController.text) ?? 0;
    final p = double.tryParse(_unitPriceController.text) ?? 0;
    return 'KES ${(q * p).toStringAsFixed(0)}';
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && _selectedSourceId != null) {
      context.read<RevenueBloc>().add(
            AddRevenueEvent(
              source: _source,
              sourceId: _selectedSourceId!,
              type: _typeController.text,
              quantity: double.parse(_quantityController.text),
              unitPrice: double.parse(_unitPriceController.text),
              date: _selectedDate,
              notes: _notesController.text,
            ),
          );
    }
  }
}
