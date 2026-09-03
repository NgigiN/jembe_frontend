import 'package:farm_tracker/core/constants/harvest_units.dart';
import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/validation/parse.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_picker_with_add.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/season_page.dart';
import 'package:farm_tracker/features/farm/presentation/utils/source_context_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HarvestPage extends StatefulWidget {
  const HarvestPage({super.key, this.seasonId});
  final String? seasonId;

  @override
  State<HarvestPage> createState() => _HarvestPageState();
}

class _HarvestPageState extends State<HarvestPage> {
  @override
  void initState() {
    super.initState();
    context.read<HarvestBloc>().add(GetHarvestsEvent(seasonId: widget.seasonId));
    context.read<SeasonBloc>().add(GetSeasonsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final seasons = context.watch<SeasonBloc>().state;
    final seasonList =
        seasons is SeasonLoaded ? seasons.seasons : <Season>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harvest Records'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<HarvestBloc, HarvestState>(
        listener: (context, state) {
          if (state is HarvestLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(context, state.successMessage!),
            );
          } else if (state is HarvestError && state.harvests.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(context, state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is HarvestLoading && state.harvests.isEmpty) {
            return const SkeletonEntityList(icon: Icons.agriculture);
          }

          if (state is HarvestError && state.harvests.isEmpty) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<HarvestBloc>().add(
                    GetHarvestsEvent(seasonId: widget.seasonId),
                  ),
            );
          }

          if (state is HarvestLoaded || state is HarvestLoading) {
            final harvests = state.harvests;
            if (harvests.isEmpty) {
              return const EntityEmptyView(
                icon: Icons.agriculture,
                title: 'No harvests recorded yet',
                subtitle: 'Tap + to record your first harvest',
              );
            }

            return ListView.builder(
              padding: context.scrollListPadding(forFab: true),
              itemCount: harvests.length,
              itemBuilder: (context, index) {
                final harvest = harvests[index];
                final seasonLabel =
                    seasonName(seasonList, harvest.seasonId);
                return EntityCard(
                  icon: Icons.agriculture,
                  iconColor: AppColors.plantCategory,
                  title:
                      '${_formatQuantity(harvest.quantity)} ${harvest.unit}',
                  subtitle:
                      '$seasonLabel · ${_formatDate(harvest.date)}',
                  onTap: () => _showHarvestDetails(
                    context,
                    harvest,
                    seasonLabel: seasonLabel,
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => _showHarvestForm(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showHarvestDetails(
    BuildContext context,
    Harvest harvest, {
    required String seasonLabel,
  }) {
    EntityDetailsSheet.show(
      context: context,
      title: '${_formatQuantity(harvest.quantity)} ${harvest.unit}',
      details: [
        EntityDetailRow('Season', seasonLabel),
        EntityDetailRow(
          'Quantity',
          '${_formatQuantity(harvest.quantity)} ${harvest.unit}',
          isPrimary: true,
        ),
        EntityDetailRow('Date', _formatDate(harvest.date)),
        if (harvest.notes != null && harvest.notes!.isNotEmpty)
          EntityDetailRow('Notes', harvest.notes!),
      ],
      onEdit: () => _showHarvestForm(context, harvest: harvest),
      onDelete: () => _confirmDelete(context, harvest),
    );
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }
    return quantity.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _confirmDelete(BuildContext context, Harvest harvest) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Harvest',
      message:
          'Delete ${_formatQuantity(harvest.quantity)} ${harvest.unit}? This cannot be undone.',
    );
    if ((confirmed ?? false) && context.mounted) {
      SuccessFeedback.deleted();
      context.read<HarvestBloc>().add(DeleteHarvestEvent(harvest.id));
    }
  }

  Future<void> _showHarvestForm(
    BuildContext context, {
    Harvest? harvest,
  }) async {
    final seasonState = context.read<SeasonBloc>().state;
    final seasons =
        seasonState is SeasonLoaded ? seasonState.seasons : <Season>[];

    if (seasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least one season first'),
          backgroundColor: context.statusColors.warning,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController(
      text: harvest != null ? _formatQuantity(harvest.quantity) : '',
    );
    final notesController = TextEditingController(text: harvest?.notes ?? '');
    final customUnitController = TextEditingController();
    String? selectedSeasonId = harvest?.seasonId ?? widget.seasonId ?? seasons.first.id;
    var selectedUnit = harvest?.unit ?? harvestUnitPresets.first;
    if (!harvestUnitPresets.contains(selectedUnit)) {
      customUnitController.text = selectedUnit;
      selectedUnit = harvestUnitOther;
    }
    var selectedDate = harvest?.date ?? DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => EntityFormSheet.container(
          context: context,
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      harvest == null ? 'Record Harvest' : 'Edit Harvest',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: EntityFormSheet.scrollableForm(
                    context: context,
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          BlocBuilder<SeasonBloc, SeasonState>(
                            builder: (context, seasonState) {
                              final liveSeasons = seasonState is SeasonLoaded
                                  ? seasonState.seasons
                                  : seasons;
                              return EntityPickerWithAdd<Season>(
                                items: liveSeasons,
                                selectedId: selectedSeasonId,
                                idOf: (season) => season.id,
                                labelOf: (season) => season.name,
                                labelText: 'Season *',
                                validator: (value) => requiredSelection(
                                  value,
                                  fieldLabel: 'season',
                                ),
                                onChanged: (value) {
                                  setState(() => selectedSeasonId = value);
                                },
                                onAddNew: showAddSeasonDialog,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          ValidatedDecimalField(
                            controller: quantityController,
                            labelText: 'Quantity *',
                            validator: (value) =>
                                positiveDecimal(value, fieldLabel: 'Quantity'),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: selectedUnit,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Unit *',
                            ),
                            items: [
                              ...harvestUnitPresets.map(
                                (unit) => DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit),
                                ),
                              ),
                              const DropdownMenuItem<String>(
                                value: harvestUnitOther,
                                child: Text('Other'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => selectedUnit = value ?? 'kg');
                            },
                          ),
                          if (selectedUnit == harvestUnitOther) ...[
                            const SizedBox(height: 16),
                            ValidatedNameField(
                              controller: customUnitController,
                              labelText: 'Custom Unit *',
                              hintText: 'e.g., baskets',
                              validator: (value) {
                                if (selectedUnit != harvestUnitOther) {
                                  return null;
                                }
                                return requiredName(
                                  value,
                                  fieldLabel: 'Custom unit',
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          FormField<DateTime>(
                            initialValue: selectedDate,
                            validator: (value) => validateDateNotInFuture(
                              value,
                              fieldLabel: 'Harvest date',
                            ),
                            builder: (field) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Harvest Date *'),
                                  subtitle: Text(_formatDate(selectedDate)),
                                  trailing:
                                      const Icon(Icons.calendar_today),
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() => selectedDate = date);
                                      field.didChange(date);
                                    }
                                  },
                                ),
                                if (field.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 8,
                                    ),
                                    child: Text(
                                      field.errorText!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ValidatedNotesField(
                            controller: notesController,
                            labelText: 'Notes (Optional)',
                            validator: optionalNotes,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }

                      final quantity =
                          parsePositiveDecimal(quantityController.text)!;
                      final unit = selectedUnit == harvestUnitOther
                          ? sanitizeText(customUnitController.text)
                          : selectedUnit;
                      final notes =
                          sanitizeOptionalText(notesController.text);

                      if (harvest == null) {
                        final newHarvest = HarvestModel.create(
                          seasonId: selectedSeasonId!,
                          quantity: quantity,
                          unit: unit,
                          date: selectedDate,
                          notes: notes,
                        );
                        SuccessFeedback.saved();
                        context
                            .read<HarvestBloc>()
                            .add(AddHarvestEvent(newHarvest));
                      } else {
                        final updatedHarvest = HarvestModel(
                          id: harvest.id,
                          seasonId: selectedSeasonId!,
                          quantity: quantity,
                          unit: unit,
                          date: selectedDate,
                          notes: notes,
                          revenueId: harvest.revenueId,
                          createdAt: harvest.createdAt,
                          updatedAt: DateTime.now(),
                        );
                        SuccessFeedback.saved();
                        context
                            .read<HarvestBloc>()
                            .add(UpdateHarvestEvent(updatedHarvest));
                      }

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      harvest == null ? 'Record Harvest' : 'Update Harvest',
                      style: const TextStyle(
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
}