import 'dart:async';

import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
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
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_type_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/herd_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/input_page.dart';
import 'package:farm_tracker/features/farm/presentation/utils/source_context_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the standard "Add Animal" form and resolves once it closes: the
/// new animal's id if the add succeeded, or null if the sheet was
/// dismissed without submitting.
Future<String?> showAddAnimalDialog(BuildContext context) async {
  final bloc = context.read<AnimalBloc>();
  final beforeIds = bloc.state.animals.map((animal) => animal.id).toSet();
  String? newId;

  final subscription = bloc.stream.listen((state) {
    if (state is AnimalLoaded && state.successMessage == 'Animal added') {
      for (final animal in state.animals) {
        if (!beforeIds.contains(animal.id)) {
          newId = animal.id;
          break;
        }
      }
    }
  });

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final animalTypeIdNotifier = ValueNotifier<String?>(null);
  final herdIdNotifier = ValueNotifier<String?>(null);
  var selectedBirthDate = DateTime.now();
  String? selectedSex;
  String? selectedAcquisitionSource;

  final animalTypes = context.read<AnimalTypeBloc>().state.animalTypes;
  final herds = context.read<HerdBloc>().state.herds;

  String? committedHerdId;
  String? committedAcquisitionSource;

  await EntityFormSheet.show(
    context: context,
    title: 'Add New Animal',
    submitLabel: 'Add Animal',
    formKey: formKey,
    fields: _animalFormFields(
      nameController: nameController,
      animalTypes: animalTypes,
      herds: herds,
      animalTypeIdNotifier: animalTypeIdNotifier,
      herdIdNotifier: herdIdNotifier,
      selectedBirthDate: selectedBirthDate,
      selectedSex: selectedSex,
      selectedAcquisitionSource: selectedAcquisitionSource,
      onBirthDateChanged: (value) => selectedBirthDate = value,
      onSexChanged: (value) => selectedSex = value,
      onAcquisitionSourceChanged: (value) => selectedAcquisitionSource = value,
    ),
    onSubmit: (sheetContext) async {
      final userId = await UserUtils.getCurrentUserId();
      if (userId == null) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          AppSnackBar.error(sheetContext, 'User not authenticated'),
        );
        return false;
      }
      committedHerdId = herdIdNotifier.value;
      committedAcquisitionSource = selectedAcquisitionSource;
      final animal = AnimalModel.create(
        userId: userId,
        name: sanitizeText(nameController.text),
        animalTypeId: animalTypeIdNotifier.value!,
        herdId: herdIdNotifier.value!,
        birthDate: selectedBirthDate,
        sex: selectedSex,
        acquisitionSource: selectedAcquisitionSource,
      );
      bloc.add(AddAnimalEvent(animal));
      final s = await bloc.stream.firstWhere(
        (s) => (s is AnimalLoaded && s.successMessage != null) || s is AnimalError,
      );
      return s is AnimalLoaded;
    },
  );

  await subscription.cancel();

  if (committedAcquisitionSource == 'bought' && newId != null && context.mounted) {
    unawaited(
      showAddInputDialog(
        context,
        sourceType: 'animal',
        lockedHerdId: committedHerdId,
        lockedAnimalId: int.tryParse(newId!),
      ),
    );
  }

  return newId;
}

List<Widget> _animalFormFields({
  required TextEditingController nameController,
  required List<AnimalType> animalTypes,
  required List<Herd> herds,
  required ValueNotifier<String?> animalTypeIdNotifier,
  required ValueNotifier<String?> herdIdNotifier,
  required DateTime selectedBirthDate,
  required ValueChanged<DateTime> onBirthDateChanged, String? selectedSex,
  String? selectedAcquisitionSource,
  ValueChanged<String?>? onSexChanged,
  ValueChanged<String?>? onAcquisitionSourceChanged,
}) {
  return [
    ValidatedNameField(
      controller: nameController,
      labelText: 'Name *',
      validator: requiredName,
    ),
    const SizedBox(height: 16),
    ListenableBuilder(
      listenable: Listenable.merge([animalTypeIdNotifier, herdIdNotifier]),
      builder: (context, _) {
        final filteredHerds = herds
            .where((herd) =>
                animalTypeIdNotifier.value == null ||
                herd.animalTypeId == animalTypeIdNotifier.value)
            .toList();
        return Column(
          children: [
            EntityPickerWithAdd<AnimalType>(
              items: animalTypes,
              selectedId: animalTypeIdNotifier.value,
              idOf: (type) => type.id,
              labelOf: (type) => type.name,
              labelText: 'Animal Type *',
              validator: (value) =>
                  requiredSelection(value, fieldLabel: 'animal type'),
              onChanged: (value) {
                animalTypeIdNotifier.value = value;
                final stillValid = herds.any((herd) =>
                    herd.id == herdIdNotifier.value &&
                    herd.animalTypeId == value);
                if (!stillValid) herdIdNotifier.value = null;
              },
              onAddNew: showAddAnimalTypeDialog,
            ),
            const SizedBox(height: 16),
            EntityPickerWithAdd<Herd>(
              items: filteredHerds,
              selectedId: herdIdNotifier.value,
              idOf: (herd) => herd.id,
              labelOf: (herd) => '${herd.name} (${herd.location})',
              labelText: 'Herd *',
              validator: (value) => requiredSelection(value, fieldLabel: 'herd'),
              onChanged: (value) => herdIdNotifier.value = value,
              onAddNew: showAddHerdDialog,
            ),
          ],
        );
      },
    ),
    const SizedBox(height: 16),
    FormField<DateTime>(
      initialValue: selectedBirthDate,
      builder: (field) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Birth Date'),
        subtitle: Text(_formatDate(selectedBirthDate)),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final date = await showDatePicker(
            context: field.context,
            initialDate: selectedBirthDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (date != null) {
            onBirthDateChanged(date);
            field.didChange(date);
          }
        },
      ),
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      key: const Key('animal-sex-field'),
      initialValue: selectedSex,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Sex (Optional)',
      ),
      items: const [
        DropdownMenuItem(value: 'male', child: Text('Male')),
        DropdownMenuItem(value: 'female', child: Text('Female')),
      ],
      onChanged: onSexChanged,
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      key: const Key('animal-acquisition-source-field'),
      initialValue: selectedAcquisitionSource,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Acquisition Source (Optional)',
      ),
      items: const [
        DropdownMenuItem(value: 'bought', child: Text('Bought')),
        DropdownMenuItem(value: 'bredOnFarm', child: Text('Bred on Farm')),
        DropdownMenuItem(value: 'gift', child: Text('Gift')),
      ],
      onChanged: onAcquisitionSourceChanged,
    ),
  ];
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

class AnimalPage extends StatefulWidget {
  const AnimalPage({super.key});

  @override
  State<AnimalPage> createState() => _AnimalPageState();
}

class _AnimalPageState extends State<AnimalPage> {
  @override
  void initState() {
    super.initState();
    final animalBloc = context.read<AnimalBloc>();
    if (animalBloc.state is! AnimalLoaded) {
      animalBloc.add(GetAnimalsEvent());
    }
    final animalTypeBloc = context.read<AnimalTypeBloc>();
    if (animalTypeBloc.state is! AnimalTypeLoaded) {
      animalTypeBloc.add(GetAnimalTypesEvent());
    }
    final herdBloc = context.read<HerdBloc>();
    if (herdBloc.state is! HerdLoaded) {
      herdBloc.add(GetHerdsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalTypeState = context.watch<AnimalTypeBloc>().state;
    final animalTypes = animalTypeState.animalTypes;
    final herdState = context.watch<HerdBloc>().state;
    final herds = herdState.herds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final animalBloc = context.read<AnimalBloc>()
            ..add(GetAnimalsEvent());
          context.read<AnimalTypeBloc>().add(GetAnimalTypesEvent());
          context.read<HerdBloc>().add(GetHerdsEvent());
          await animalBloc.stream.firstWhere(
            (s) => s is AnimalLoaded || s is AnimalError,
          );
        },
        child: BlocConsumer<AnimalBloc, AnimalState>(
        listener: (context, state) {
          if (state is AnimalLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(context, state.successMessage!),
            );
          } else if (state is AnimalError && state.animals.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(context, state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is AnimalLoading && state.animals.isEmpty) {
            return const SkeletonEntityList(icon: Icons.pets);
          }

          if (state is AnimalError && state.animals.isEmpty) {
            return _scrollableEmptyState(
              EntityErrorView(
                message: state.message,
                onRetry: () => context.read<AnimalBloc>().add(GetAnimalsEvent()),
              ),
            );
          }

          final animals = state.animals;
          if (animals.isEmpty) {
            return _scrollableEmptyState(
              const EntityEmptyView(
                icon: Icons.pets,
                title: 'No animals registered yet',
                subtitle: 'Tap the + button to add your first animal',
              ),
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.scrollListPadding(forFab: true),
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];
              return EntityCard(
                icon: Icons.pets,
                iconColor: AppColors.animalCategory,
                title: animal.name,
                subtitle: _animalSubtitle(animal, animalTypes, herds),
                onTap: () => _showAnimalDetails(context, animal, animalTypes, herds),
              );
            },
          );
        },
        ),
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => showAddAnimalDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _animalSubtitle(Animal animal, List<AnimalType> animalTypes, List<Herd> herds) {
    return '${animalTypeName(animalTypes, animal.animalTypeId)} · ${herdName(herds, animal.herdId)}';
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

  void _showAnimalDetails(
    BuildContext context,
    Animal animal,
    List<AnimalType> animalTypes,
    List<Herd> herds,
  ) {
    EntityDetailsSheet.show(
      context: context,
      title: animal.name,
      details: [
        EntityDetailRow('Type', animalTypeName(animalTypes, animal.animalTypeId)),
        EntityDetailRow('Herd', herdName(herds, animal.herdId)),
        EntityDetailRow('Birth Date', _formatDate(animal.birthDate)),
        EntityDetailRow(
          'Sex',
          animal.sex?.isNotEmpty ?? false
              ? animal.sex![0].toUpperCase() + animal.sex!.substring(1)
              : '—',
        ),
        EntityDetailRow(
          'Acquisition Source',
          animal.acquisitionSource?.isNotEmpty ?? false
              ? animal.acquisitionSource![0].toUpperCase() +
                  animal.acquisitionSource!.substring(1)
              : '—',
        ),
      ],
      onEdit: () => _showEditAnimalDialog(animal, animalTypes, herds),
      onDelete: () => _showDeleteConfirmation(animal),
    );
  }

  Future<void> _showEditAnimalDialog(
    Animal animal,
    List<AnimalType> animalTypes,
    List<Herd> herds,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: animal.name);
    final animalTypeIdNotifier = ValueNotifier<String?>(animal.animalTypeId);
    final herdIdNotifier = ValueNotifier<String?>(animal.herdId);
    var selectedBirthDate = animal.birthDate;
    var selectedSex = animal.sex;
    var selectedAcquisitionSource = animal.acquisitionSource;
    final wasBought = animal.acquisitionSource == 'bought';
    var committedNowBought = false;
    String? committedHerdId;

    await EntityFormSheet.show(
      context: context,
      title: 'Edit Animal',
      heightFactor: 0.7,
      submitLabel: 'Update Animal',
      formKey: formKey,
      fields: _animalFormFields(
        nameController: nameController,
        animalTypes: animalTypes,
        herds: herds,
        animalTypeIdNotifier: animalTypeIdNotifier,
        herdIdNotifier: herdIdNotifier,
        selectedBirthDate: selectedBirthDate,
        selectedSex: selectedSex,
        selectedAcquisitionSource: selectedAcquisitionSource,
        onBirthDateChanged: (value) => selectedBirthDate = value,
        onSexChanged: (value) => selectedSex = value,
        onAcquisitionSourceChanged: (value) => selectedAcquisitionSource = value,
      ),
      onSubmit: (sheetContext) async {
        final herdId = herdIdNotifier.value!;
        final nowBought = selectedAcquisitionSource == 'bought';
        final updatedAnimal = AnimalModel(
          id: animal.id,
          userId: animal.userId,
          name: sanitizeText(nameController.text),
          animalTypeId: animalTypeIdNotifier.value!,
          herdId: herdId,
          birthDate: selectedBirthDate,
          sex: selectedSex,
          acquisitionSource: selectedAcquisitionSource,
          createdAt: animal.createdAt,
          updatedAt: DateTime.now(),
        );
        final bloc = context.read<AnimalBloc>()
          ..add(UpdateAnimalEvent(updatedAnimal));
        final s = await bloc.stream.firstWhere(
          (s) => (s is AnimalLoaded && s.successMessage != null) || s is AnimalError,
        );
        if (s is AnimalLoaded) {
          committedNowBought = nowBought;
          committedHerdId = herdId;
        }
        return s is AnimalLoaded;
      },
    );

    if (!wasBought && committedNowBought && context.mounted) {
      unawaited(
        showAddInputDialog(
          context,
          sourceType: 'animal',
          lockedHerdId: committedHerdId,
          lockedAnimalId: int.tryParse(animal.id),
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(Animal animal) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Animal',
      message:
          'Are you sure you want to delete "${animal.name}"? This action cannot be undone.',
    );
    if (confirmed ?? false) {
      SuccessFeedback.deleted();
      context.read<AnimalBloc>().add(DeleteAnimalEvent(animal.id));
    }
  }
}
