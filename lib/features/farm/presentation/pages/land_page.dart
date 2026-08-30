import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/validation/field_limits.dart';
import 'package:farm_tracker/core/validation/input_formatters.dart';
import 'package:farm_tracker/core/validation/parse.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';

/// Opens the standard "Add Land" form and resolves once it closes: the new
/// land's id if the add succeeded, or null if the sheet was dismissed
/// without submitting. Lets other pickers (e.g. Season's land dropdown)
/// reuse this exact flow instead of duplicating it.
Future<String?> showAddLandDialog(BuildContext context) async {
  final bloc = context.read<LandBloc>();
  final beforeIds = bloc.state.lands.map((land) => land.id).toSet();
  String? newId;

  final subscription = bloc.stream.listen((state) {
    if (state is LandLoaded && state.successMessage == 'Land added') {
      for (final land in state.lands) {
        if (!beforeIds.contains(land.id)) {
          newId = land.id;
          break;
        }
      }
    }
  });

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final sizeController = TextEditingController();
  final locationController = TextEditingController();
  final soilTypeController = TextEditingController();
  String? selectedTenureType;

  await EntityFormSheet.show(
    context: context,
    title: 'Add New Land',
    submitLabel: 'Add Land',
    formKey: formKey,
    fields: _LandPageState._landFormFields(
      nameController: nameController,
      sizeController: sizeController,
      locationController: locationController,
      soilTypeController: soilTypeController,
      onTenureTypeChanged: (value) => selectedTenureType = value,
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
      final land = LandModel.create(
        userId: userId,
        name: sanitizeText(nameController.text),
        size: parseOptionalNonNegativeDecimal(sizeController.text),
        location: sanitizeOptionalText(locationController.text),
        soilType: sanitizeOptionalText(soilTypeController.text),
        tenureType: selectedTenureType,
      );
      bloc.add(AddLandEvent(land));
      Navigator.pop(sheetContext);
    },
  );

  await subscription.cancel();
  return newId;
}

class LandPage extends StatefulWidget {
  const LandPage({super.key});

  @override
  State<LandPage> createState() => _LandPageState();
}

class _LandPageState extends State<LandPage> {
  @override
  void initState() {
    super.initState();
    context.read<LandBloc>().add(GetLandsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Land Management'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<LandBloc, LandState>(
        listener: (context, state) {
          if (state is LandLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(state.successMessage!),
            );
          } else if (state is LandError && state.lands.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is LandLoading && state.lands.isEmpty) {
            return const SkeletonEntityList(icon: Icons.landscape);
          }

          if (state is LandError && state.lands.isEmpty) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<LandBloc>().add(GetLandsEvent()),
            );
          }

          final lands = state.lands;
          if (lands.isEmpty) {
            return EntityEmptyView(
              icon: Icons.landscape,
              title: 'No lands registered yet',
              subtitle: 'Tap the + button to add your first land',
            );
          }

          return ListView.builder(
            padding: context.scrollListPadding(forFab: true),
            itemCount: lands.length,
            itemBuilder: (context, index) {
              final land = lands[index];
              return EntityCard(
                icon: Icons.landscape,
                iconColor: AppColors.plantCategory,
                title: land.name,
                subtitle: _landSubtitle(land),
                onTap: () => _showLandDetails(land),
              );
            },
          );
        },
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => _showAddLandDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _landSubtitle(Land land) {
    final parts = <String>[];
    if (land.size != null) parts.add('${land.size} acres');
    if (land.location != null && land.location!.isNotEmpty) {
      parts.add(land.location!);
    }
    return parts.isEmpty ? 'No details' : parts.join(' · ');
  }

  void _showLandDetails(Land land) {
    EntityDetailsSheet.show(
      context: context,
      title: land.name,
      details: [
        if (land.size != null)
          EntityDetailRow('Size', '${land.size} acres'),
        EntityDetailRow(
          'Location',
          land.location?.isNotEmpty == true ? land.location! : '—',
        ),
        EntityDetailRow(
          'Soil Type',
          land.soilType?.isNotEmpty == true ? land.soilType! : '—',
        ),
        EntityDetailRow(
          'Tenure',
          land.tenureType?.isNotEmpty == true
              ? land.tenureType![0].toUpperCase() + land.tenureType!.substring(1)
              : '—',
        ),
      ],
      onEdit: () => _showEditLandDialog(land),
      onDelete: () => _showDeleteConfirmation(land),
    );
  }

  void _showAddLandDialog() {
    showAddLandDialog(context);
  }

  void _showEditLandDialog(Land land) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: land.name);
    final sizeController = TextEditingController(
      text: land.size?.toString() ?? '',
    );
    final locationController = TextEditingController(text: land.location ?? '');
    final soilTypeController = TextEditingController(text: land.soilType ?? '');
    String? selectedTenureType = land.tenureType;

    EntityFormSheet.show(
      context: context,
      title: 'Edit Land',
      heightFactor: 0.6,
      submitLabel: 'Update Land',
      formKey: formKey,
      fields: _landFormFields(
        nameController: nameController,
        sizeController: sizeController,
        locationController: locationController,
        soilTypeController: soilTypeController,
        sizeHint: 'Enter land size in acres',
        locationHint: 'Enter land location (optional)',
        soilTypeHint: 'Enter soil type (optional)',
        selectedTenureType: selectedTenureType,
        onTenureTypeChanged: (value) => selectedTenureType = value,
      ),
      onSubmit: (sheetContext) async {
        final updatedLand = LandModel(
          id: land.id,
          userId: land.userId,
          name: sanitizeText(nameController.text),
          size: parseOptionalNonNegativeDecimal(sizeController.text),
          location: sanitizeOptionalText(locationController.text),
          soilType: sanitizeOptionalText(soilTypeController.text),
          tenureType: selectedTenureType,
          createdAt: land.createdAt,
          updatedAt: DateTime.now(),
        );
        context.read<LandBloc>().add(UpdateLandEvent(updatedLand));
        Navigator.pop(sheetContext);
      },
    );
  }

  static List<Widget> _landFormFields({
    required TextEditingController nameController,
    required TextEditingController sizeController,
    required TextEditingController locationController,
    required TextEditingController soilTypeController,
    String? sizeHint,
    String? locationHint,
    String? soilTypeHint,
    String? selectedTenureType,
    ValueChanged<String?>? onTenureTypeChanged,
  }) {
    return [
      ValidatedNameField(
        controller: nameController,
        labelText: 'Land Name *',
        validator: (value) => requiredName(value, fieldLabel: 'Land name'),
      ),
      const SizedBox(height: 16),
      ValidatedDecimalField(
        controller: sizeController,
        labelText: 'Size (acres)',
        hintText: sizeHint,
        validator: (value) =>
            optionalNonNegativeDecimal(value, fieldLabel: 'Size'),
      ),
      const SizedBox(height: 16),
      ValidatedLocationField(
        controller: locationController,
        labelText: 'Location',
        hintText: locationHint,
        validator: (value) => optionalLocation(value),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: soilTypeController,
        decoration: InputDecoration(
          labelText: 'Soil Type',
          hintText: soilTypeHint,
          border: const OutlineInputBorder(),
        ),
        validator: optionalSoilType,
        inputFormatters: shortLabelFormatters(maxLength: FieldLimits.soilTypeMax),
        maxLength: FieldLimits.soilTypeMax,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
            null,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: selectedTenureType,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tenure (Optional)',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'owned', child: Text('Owned')),
          DropdownMenuItem(value: 'rented', child: Text('Rented')),
        ],
        onChanged: onTenureTypeChanged,
      ),
    ];
  }

  void _showDeleteConfirmation(Land land) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Land',
      message:
          'Are you sure you want to delete "${land.name}"${land.location != null ? ' (${land.location})' : ''}? This action cannot be undone.',
    );
    if (confirmed == true) {
      context.read<LandBloc>().add(DeleteLandEvent(land.id));
    }
  }
}
