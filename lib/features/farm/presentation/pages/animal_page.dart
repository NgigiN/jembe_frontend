import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_picker_with_add.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_type_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/herd_page.dart';
import 'package:farm_tracker/features/farm/presentation/utils/source_context_resolver.dart';

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
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
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
      Navigator.pop(sheetContext);
    },
  );

  await subscription.cancel();
  return newId;
}

List<Widget> _animalFormFields({
  required TextEditingController nameController,
  required List<AnimalType> animalTypes,
  required List<Herd> herds,
  required ValueNotifier<String?> animalTypeIdNotifier,
  required ValueNotifier<String?> herdIdNotifier,
  required DateTime selectedBirthDate,
  String? selectedSex,
  String? selectedAcquisitionSource,
  required ValueChanged<DateTime> onBirthDateChanged,
  ValueChanged<String?>? onSexChanged,
  ValueChanged<String?>? onAcquisitionSourceChanged,
}) {
  return [
    ValidatedNameField(
      controller: nameController,
      labelText: 'Name *',
      validator: (value) => requiredName(value, fieldLabel: 'Name'),
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
      decoration: const InputDecoration(
        labelText: 'Sex (Optional)',
        border: OutlineInputBorder(),
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
      decoration: const InputDecoration(
        labelText: 'Acquisition Source (Optional)',
        border: OutlineInputBorder(),
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
    context.read<AnimalBloc>().add(GetAnimalsEvent());
    context.read<AnimalTypeBloc>().add(GetAnimalTypesEvent());
    context.read<HerdBloc>().add(GetHerdsEvent());
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
      body: BlocConsumer<AnimalBloc, AnimalState>(
        listener: (context, state) {
          if (state is AnimalLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(state.successMessage!),
            );
          } else if (state is AnimalError && state.animals.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is AnimalLoading && state.animals.isEmpty) {
            return const SkeletonEntityList(icon: Icons.pets);
          }

          if (state is AnimalError && state.animals.isEmpty) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<AnimalBloc>().add(GetAnimalsEvent()),
            );
          }

          final animals = state.animals;
          if (animals.isEmpty) {
            return EntityEmptyView(
              icon: Icons.pets,
              title: 'No animals registered yet',
              subtitle: 'Tap the + button to add your first animal',
            );
          }

          return ListView.builder(
            padding: context.scrollListPadding(forFab: true),
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];
              return EntityCard(
                icon: Icons.pets,
                iconColor: AppColors.animalCategory,
                title: animal.name,
                subtitle: _animalSubtitle(animal, animalTypes, herds),
                onTap: () {},
              );
            },
          );
        },
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
}
