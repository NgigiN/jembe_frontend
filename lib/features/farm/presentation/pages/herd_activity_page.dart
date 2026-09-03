import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/core/validation/parse.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_picker_with_add.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/herd_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

    final count = parsePositiveInt(_countController.text);
    if (count == null) return;

    context.read<HerdActivityBloc>().add(
      AddHerdActivityEvent(
        herdId: _selectedHerdId!,
        activityType: _activityType,
        count: count,
        date: _selectedDate,
        notes: sanitizeOptionalText(_notesController.text),
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
                AppSnackBar.success(context, state.message),
              );
              context.read<HerdBloc>().add(GetHerdsEvent());
              Navigator.pop(context);
            } else if (state is HerdActivityError) {
              ScaffoldMessenger.of(context).showSnackBar(
                AppSnackBar.error(context, state.message),
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
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Divider(height: 32),
                            EntityPickerWithAdd<Herd>(
                              items: herds,
                              selectedId: _selectedHerdId,
                              idOf: (herd) => herd.id,
                              labelOf: (herd) =>
                                  '${herd.name} (Current: ${herd.currentHeadCount})',
                              labelText: 'Select Herd *',
                              prefixIcon: const Icon(Icons.pets),
                              onChanged: (value) {
                                setState(() => _selectedHerdId = value);
                              },
                              validator: (value) =>
                                  requiredSelection(value, fieldLabel: 'herd'),
                              onAddNew: showAddHerdDialog,
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
                                    selectedColor: context.statusColors.positive
                                        .withValues(alpha: 0.15),
                                    checkmarkColor: context.statusColors.positive,
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
                                    selectedColor: context.statusColors.negative
                                        .withValues(alpha: 0.15),
                                    checkmarkColor: context.statusColors.negative,
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
                            ValidatedIntegerField(
                              controller: _countController,
                              labelText: 'Count *',
                              hintText: 'Number of animals affected',
                              prefixIcon: const Icon(Icons.tag),
                              validator: (value) {
                                if (_activityType == 'fatality') {
                                  return positiveIntMax(
                                    value,
                                    max: selectedHerd.currentHeadCount,
                                  );
                                }
                                return positiveInt(value);
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
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            ValidatedNotesField(
                              controller: _notesController,
                              labelText: 'Notes / Reason',
                              validator: optionalNotes,
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submitForm,
                                child: isLoading
                                    ? CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(
                                          Theme.of(context).colorScheme.onPrimary,
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