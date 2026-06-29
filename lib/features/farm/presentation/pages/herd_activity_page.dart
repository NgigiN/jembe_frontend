import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';

class HerdActivityPage extends StatefulWidget {
  const HerdActivityPage({super.key});

  @override
  State<HerdActivityPage> createState() => _HerdActivityPageState();
}

class _HerdActivityPageState extends State<HerdActivityPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedHerdId;
  String _activityType = 'birth';
  final _countController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    context.read<HerdBloc>().add(GetHerdsEvent());
  }

  @override
  void dispose() {
    _countController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHerdId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a herd'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final count = int.tryParse(_countController.text.trim()) ?? 0;
    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Count must be greater than zero'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    context.read<HerdActivityBloc>().add(
      AddHerdActivityEvent(
        herdId: _selectedHerdId!,
        activityType: _activityType,
        count: count,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Herd Activity'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<HerdActivityBloc, HerdActivityState>(
          listener: (context, state) {
            if (state is HerdActivitySuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              context.read<HerdBloc>().add(GetHerdsEvent());
              Navigator.pop(context);
            } else if (state is HerdActivityError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is HerdActivityLoading;

            return BlocBuilder<HerdBloc, HerdState>(
              builder: (context, herdState) {
                if (herdState is HerdLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (herdState is! HerdLoaded || herdState.herds.isEmpty) {
                  return const EntityEmptyView(
                    icon: Icons.pets,
                    title: 'No herds registered yet',
                    subtitle:
                        'Register a herd first, then return here to log births or fatalities',
                  );
                }

                final herds = herdState.herds;
                _selectedHerdId ??= herds.first.id;

                final selectedHerd = herds.cast<Herd>().firstWhere(
                  (herd) => herd.id == _selectedHerdId,
                  orElse: () => herds.first,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.animalCategory
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.pets,
                                    color: AppColors.animalCategory,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Record Birth or Fatality',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Logging events automatically updates the herd headcount.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Divider(height: 32),
                            DropdownButtonFormField<String>(
                              value: _selectedHerdId,
                              decoration: const InputDecoration(
                                labelText: 'Select Herd *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.pets),
                              ),
                              items: herds
                                  .map(
                                    (herd) => DropdownMenuItem<String>(
                                      value: herd.id,
                                      child: Text(
                                        '${herd.name} (Current: ${herd.currentHeadCount})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedHerdId = value);
                              },
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Activity Type *',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.child_care, size: 18),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Birth',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: _activityType == 'birth',
                                    selectedColor: Colors.green.shade100,
                                    checkmarkColor: Colors.green.shade800,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _activityType = 'birth');
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.sentiment_very_dissatisfied,
                                          size: 18,
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Fatality',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: _activityType == 'fatality',
                                    selectedColor: Colors.red.shade100,
                                    checkmarkColor: Colors.red.shade800,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(
                                          () => _activityType = 'fatality',
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _countController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Count *',
                                hintText: 'Number of animals affected',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.tag),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter the count';
                                }
                                final count = int.tryParse(value.trim());
                                if (count == null || count <= 0) {
                                  return 'Enter a positive number';
                                }
                                if (_activityType == 'fatality' &&
                                    count > selectedHerd.currentHeadCount) {
                                  return 'Fatality count cannot exceed current headcount (${selectedHerd.currentHeadCount})';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            InkWell(
                              onTap: () => _selectDate(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Notes / Reason',
                                hintText: 'e.g., Illness, Normal Birth',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.notes),
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submitForm,
                                child: isLoading
                                    ? const CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Record Activity',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
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
              },
            );
          },
        ),
    );
  }
}