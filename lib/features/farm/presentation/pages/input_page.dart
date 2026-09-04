import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/validation/parse.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/widgets/crud/cost_category_type_selector.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/utils/source_context_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the standard "Add Input" form. When [lockedHerdId] is set, the
/// Herd picker is skipped and the input is pre-scoped to that herd (and
/// optionally to a specific animal via [lockedAnimalId]).
Future<void> showAddInputDialog(
  BuildContext context, {
  String? sourceType,
  String? lockedHerdId,
  int? lockedAnimalId,
}) async {
  final formKey = GlobalKey<FormState>();
  final typeController = TextEditingController();
  final quantityController = TextEditingController();
  final costController = TextEditingController();
  final notesController = TextEditingController();
  DateTime? selectedDate = DateTime.now();
  final selectedSourceType = sourceType ?? 'plant';
  final isPlant = selectedSourceType == 'plant';
  String? selectedSeasonId;
  var selectedHerdId = lockedHerdId;

  final seasonState = context.read<SeasonBloc>().state;
  final seasons = seasonState is SeasonLoaded ? seasonState.seasons : <Season>[];

  final landState = context.read<LandBloc>().state;
  final lands = landState is LandLoaded ? landState.lands : <Land>[];

  final herdState = context.read<HerdBloc>().state;
  final herds = herdState is HerdLoaded ? herdState.herds : <Herd>[];

  if (isPlant && seasons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please add at least one season first'),
        backgroundColor: context.statusColors.warning,
      ),
    );
    return;
  }
  if (!isPlant && lockedHerdId == null && herds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please add at least one herd first'),
        backgroundColor: context.statusColors.warning,
      ),
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => EntityFormSheet.container(
        context: context,
        heightFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add New ${isPlant ? 'Plant' : 'Animal'} Input',
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
                        if (isPlant)
                          DropdownButtonFormField<String>(
                            initialValue: selectedSeasonId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Season *',
                            ),
                            items: seasons.map((season) {
                              return DropdownMenuItem<String>(
                                value: season.id,
                                child: Text(seasonDropdownLabel(season, lands)),
                              );
                            }).toList(),
                            validator: (value) =>
                                requiredSelection(value, fieldLabel: 'season'),
                            onChanged: (value) {
                              setState(() {
                                selectedSeasonId = value;
                              });
                            },
                          ),
                        if (!isPlant && lockedHerdId == null)
                          DropdownButtonFormField<String>(
                            initialValue: selectedHerdId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Herd *',
                            ),
                            items: herds.map((herd) {
                              return DropdownMenuItem<String>(
                                value: herd.id,
                                child: Text('${herd.name} (${herd.location})'),
                              );
                            }).toList(),
                            validator: (value) =>
                                requiredSelection(value, fieldLabel: 'herd'),
                            onChanged: (value) {
                              setState(() {
                                selectedHerdId = value;
                              });
                            },
                          ),
                        const SizedBox(height: 16),
                        CostCategoryTypeSelector(
                          categoryKind: 'input',
                          sourceType: selectedSourceType,
                          selectedType: typeController.text,
                          labelText: 'Input Type *',
                          validator: (value) =>
                              requiredName(value, fieldLabel: 'Input type'),
                          onTypeChanged: (value) {
                            setState(() {
                              typeController.text = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        ValidatedDecimalField(
                          controller: quantityController,
                          labelText: 'Quantity (Optional)',
                          validator: (value) => optionalNonNegativeDecimal(
                            value,
                            fieldLabel: 'Quantity',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValidatedDecimalField(
                          controller: costController,
                          labelText: 'Cost *',
                          hintText: '0.00',
                          validator: (value) =>
                              positiveDecimal(value, fieldLabel: 'Cost'),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }

                    final sourceId =
                        isPlant ? selectedSeasonId! : selectedHerdId!;

                    final input = InputModel.create(
                      sourceType: selectedSourceType,
                      sourceId: sourceId,
                      animalId: isPlant ? null : lockedAnimalId,
                      type: sanitizeText(typeController.text),
                      quantity: parseOptionalNonNegativeDecimal(
                        quantityController.text,
                      ),
                      cost: parsePositiveDecimal(costController.text)!,
                      date: selectedDate!,
                      notes: sanitizeOptionalText(notesController.text),
                    );
                    SuccessFeedback.saved();
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

class InputPage extends StatefulWidget {
  const InputPage({super.key, this.sourceType});
  final String? sourceType;

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  @override
  void initState() {
    super.initState();
    // InputBloc and CostCategoryBloc are shared, app-wide singletons whose
    // Get*Event is parameterized (sourceType / category) but whose Loaded
    // state doesn't record which parameter produced it. Guarding these on
    // "is! XLoaded" would risk skipping the fetch and showing data fetched
    // for a *different* sourceType/category (e.g. animal inputs left on
    // screen after navigating here for 'plant'), so they're always
    // re-fetched. HerdBloc/SeasonBloc/LandBloc are unparameterized and
    // safe to guard.
    context.read<InputBloc>().add(GetInputsEvent(sourceType: widget.sourceType));
    final herdBloc = context.read<HerdBloc>();
    if (herdBloc.state is! HerdLoaded) {
      herdBloc.add(GetHerdsEvent());
    }
    final seasonBloc = context.read<SeasonBloc>();
    if (seasonBloc.state is! SeasonLoaded) {
      seasonBloc.add(GetSeasonsEvent());
    }
    final landBloc = context.read<LandBloc>();
    if (landBloc.state is! LandLoaded) {
      landBloc.add(GetLandsEvent());
    }
    context.read<CostCategoryBloc>().add(
          const GetCostCategoriesEvent(category: 'input'),
        );
  }

  @override
  Widget build(BuildContext context) {
    final seasonState = context.watch<SeasonBloc>().state;
    final seasons =
        seasonState is SeasonLoaded ? seasonState.seasons : <Season>[];
    final landState = context.watch<LandBloc>().state;
    final lands = landState is LandLoaded ? landState.lands : <Land>[];
    final herdState = context.watch<HerdBloc>().state;
    final herds = herdState is HerdLoaded ? herdState.herds : <Herd>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Management'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final inputBloc = context.read<InputBloc>()
            ..add(GetInputsEvent(sourceType: widget.sourceType));
          context.read<HerdBloc>().add(GetHerdsEvent());
          context.read<SeasonBloc>().add(GetSeasonsEvent());
          context.read<LandBloc>().add(GetLandsEvent());
          context.read<CostCategoryBloc>().add(
                const GetCostCategoriesEvent(category: 'input'),
              );
          await inputBloc.stream.firstWhere(
            (s) => s is InputLoaded || s is InputError,
          );
        },
        child: BlocConsumer<InputBloc, InputState>(
        listener: (context, state) {
          if (state is InputLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(context, state.successMessage!),
            );
          } else if (state is InputError && state.inputs.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(context, state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is InputLoading && state.inputs.isEmpty) {
            return const SkeletonEntityList(icon: Icons.inventory_2);
          }

          if (state is InputError && state.inputs.isEmpty) {
            return _scrollableEmptyState(
              EntityErrorView(
                message: state.message,
                onRetry: () =>
                    context.read<InputBloc>().add(GetInputsEvent(sourceType: widget.sourceType)),
              ),
            );
          }

          final inputs = state.inputs;
          if (inputs.isEmpty) {
            return _scrollableEmptyState(
              const EntityEmptyView(
                icon: Icons.input,
                title: 'No inputs registered yet',
                subtitle: 'Tap the + button to add your first input',
              ),
            );
          }

          return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: context.scrollListPadding(forFab: true),
              itemCount: inputs.length,
              itemBuilder: (context, index) {
                final input = inputs[index];
                final isPlant = input.sourceType == 'plant';
                final categoryColor = isPlant
                    ? AppColors.plantCategory
                    : AppColors.animalCategory;
                final subtitle = isPlant
                    ? '${seasonName(seasons, input.sourceId)} · ${landNameForSeason(seasons, lands, input.sourceId)}'
                    : herdName(herds, input.sourceId);

                return EntityCard(
                  icon: Icons.input,
                  iconColor: categoryColor,
                  title: input.type,
                  subtitle: '$subtitle · ${_formatDate(input.date)}',
                  trailing: Text(
                    'Ksh ${input.cost.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  onTap: () => _showInputDetails(
                    context,
                    input,
                    seasons: seasons,
                    lands: lands,
                    herds: herds,
                  ),
                );
              },
            );
        },
        ),
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => showAddInputDialog(context, sourceType: widget.sourceType),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// Makes a non-scrollable empty/error state (a centered icon+text column)
  /// pullable: [RefreshIndicator] needs a scrollable descendant to detect
  /// the pull gesture, even when there's nothing to scroll.
  Widget _scrollableEmptyState(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showInputDetails(
    BuildContext context,
    Input input, {
    required List<Season> seasons,
    required List<Land> lands,
    required List<Herd> herds,
  }) {
    final isPlant = input.sourceType == 'plant';
    EntityDetailsSheet.show(
      context: context,
      title: input.type,
      badgeLabel: input.sourceType.toUpperCase(),
      badgeColor:
          isPlant ? AppColors.plantCategory : AppColors.animalCategory,
      details: [
        if (isPlant) ...[
          EntityDetailRow('Season', seasonName(seasons, input.sourceId)),
          EntityDetailRow(
            'Land',
            landNameForSeason(seasons, lands, input.sourceId),
          ),
        ] else
          EntityDetailRow('Herd', herdName(herds, input.sourceId)),
        if (input.quantity != null)
          EntityDetailRow('Quantity', input.quantity.toString()),
        EntityDetailRow(
          'Cost',
          'Ksh ${input.cost.toStringAsFixed(2)}',
          isPrimary: true,
        ),
        EntityDetailRow('Date', _formatDate(input.date)),
        if (input.notes != null && input.notes!.isNotEmpty)
          EntityDetailRow('Notes', input.notes!),
      ],
      onEdit: () => _showEditInputDialog(context, input),
      onDelete: () => _showDeleteConfirmation(context, input),
    );
  }

  Future<void> _showEditInputDialog(BuildContext context, Input input) async {
    final formKey = GlobalKey<FormState>();
    final typeController = TextEditingController(text: input.type);
    final quantityController = TextEditingController(
      text: input.quantity?.toString() ?? '',
    );
    final costController = TextEditingController(text: input.cost.toString());
    final notesController = TextEditingController(text: input.notes ?? '');
    DateTime? selectedDate = input.date;
    final selectedSourceType = input.sourceType;
    final isPlant = selectedSourceType == 'plant';
    var selectedSeasonId = isPlant ? input.sourceId : null;
    var selectedHerdId = isPlant ? null : input.sourceId;

    final seasonState = context.read<SeasonBloc>().state;
    final seasons =
        seasonState is SeasonLoaded ? seasonState.seasons : <Season>[];

    final landState = context.read<LandBloc>().state;
    final lands = landState is LandLoaded ? landState.lands : <Land>[];

    final herdState = context.read<HerdBloc>().state;
    final herds = herdState is HerdLoaded ? herdState.herds : <Herd>[];

    if ((isPlant && seasons.isEmpty) || (!isPlant && herds.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No seasons or herds available for editing'),
          backgroundColor: context.statusColors.warning,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => EntityFormSheet.container(
          context: context,
          heightFactor: 0.9,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit ${isPlant ? 'Plant' : 'Animal'} Input',
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
                          if (isPlant)
                            DropdownButtonFormField<String>(
                              initialValue: selectedSeasonId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Select Season *',
                              ),
                              items: seasons.map((season) {
                                return DropdownMenuItem<String>(
                                  value: season.id,
                                  child: Text(seasonDropdownLabel(season, lands)),
                                );
                              }).toList(),
                              validator: (value) =>
                                  requiredSelection(value, fieldLabel: 'season'),
                              onChanged: (value) {
                                setState(() {
                                  selectedSeasonId = value;
                                });
                              },
                            ),
                          if (!isPlant)
                            DropdownButtonFormField<String>(
                              initialValue: selectedHerdId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Select Herd *',
                              ),
                              items: herds
                                  .map<DropdownMenuItem<String>>((herd) {
                                return DropdownMenuItem<String>(
                                  value: herd.id,
                                  child: Text(
                                      '${herd.name} (${herd.location})'),
                                );
                              }).toList(),
                              validator: (value) =>
                                  requiredSelection(value, fieldLabel: 'herd'),
                              onChanged: (value) {
                                setState(() {
                                  selectedHerdId = value;
                                });
                              },
                            ),
                          const SizedBox(height: 16),
                          CostCategoryTypeSelector(
                            categoryKind: 'input',
                            sourceType: selectedSourceType,
                            selectedType: typeController.text,
                            labelText: 'Input Type *',
                            validator: (value) => requiredName(
                              value,
                              fieldLabel: 'Input type',
                            ),
                            onTypeChanged: (value) {
                              setState(() {
                                typeController.text = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          ValidatedDecimalField(
                            controller: quantityController,
                            labelText: 'Quantity (Optional)',
                            hintText: 'Enter quantity',
                            validator: (value) => optionalNonNegativeDecimal(
                              value,
                              fieldLabel: 'Quantity',
                            ),
                          ),
                          const SizedBox(height: 16),
                          ValidatedDecimalField(
                            controller: costController,
                            labelText: 'Cost *',
                            hintText: '0.00',
                            validator: (value) =>
                                positiveDecimal(value, fieldLabel: 'Cost'),
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
                                initialDate:
                                    selectedDate ?? DateTime.now(),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }

                      final sourceId =
                          isPlant ? selectedSeasonId! : selectedHerdId!;

                      final updatedInput = InputModel(
                        id: input.id,
                        sourceType: selectedSourceType,
                        sourceId: sourceId,
                        animalId: isPlant ? null : 0,
                        type: sanitizeText(typeController.text),
                        quantity: parseOptionalNonNegativeDecimal(
                          quantityController.text,
                        ),
                        cost: parsePositiveDecimal(costController.text)!,
                        date: selectedDate!,
                        notes: sanitizeOptionalText(notesController.text),
                        createdAt: input.createdAt,
                        updatedAt: DateTime.now(),
                      );

                      SuccessFeedback.saved();
                      context
                          .read<InputBloc>()
                          .add(UpdateInputEvent(updatedInput));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimary,
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

  Future<void> _showDeleteConfirmation(BuildContext context, Input input) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Input',
      message:
          'Are you sure you want to delete this ${input.type.toLowerCase()} input? This action cannot be undone.',
    );
    if (confirmed ?? false) {
      SuccessFeedback.deleted();
      context.read<InputBloc>().add(DeleteInputEvent(input.id));
    }
  }

}
