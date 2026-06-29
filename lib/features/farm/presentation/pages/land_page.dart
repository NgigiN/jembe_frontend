import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';

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
      body: BlocBuilder<LandBloc, LandState>(
        builder: (context, state) {
          if (state is LandLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is LandError) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<LandBloc>().add(GetLandsEvent()),
            );
          }

          if (state is LandLoaded) {
            if (state.lands.isEmpty) {
              return EntityEmptyView(
                icon: Icons.landscape,
                title: 'No lands registered yet',
                subtitle: 'Tap the + button to add your first land',
              );
            }

            return ListView.builder(
              padding: context.scrollListPadding(forFab: true),
              itemCount: state.lands.length,
              itemBuilder: (context, index) {
                final land = state.lands[index];
                return EntityCard(
                  icon: Icons.landscape,
                  iconColor: AppColors.plantCategory,
                  title: land.name,
                  subtitle: _landSubtitle(land),
                  onTap: () => _showLandDetails(land),
                );
              },
            );
          }

          return const SizedBox.shrink();
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
      ],
      onEdit: () => _showEditLandDialog(land),
      onDelete: () => _showDeleteConfirmation(land),
    );
  }

  void _showAddLandDialog() {
    final nameController = TextEditingController();
    final sizeController = TextEditingController();
    final locationController = TextEditingController();
    final soilTypeController = TextEditingController();

    EntityFormSheet.show(
      context: context,
      title: 'Add New Land',
      submitLabel: 'Add Land',
      fields: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Land Name *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: sizeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Size (acres)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: locationController,
          decoration: const InputDecoration(
            labelText: 'Location',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: soilTypeController,
          decoration: const InputDecoration(
            labelText: 'Soil Type',
            border: OutlineInputBorder(),
          ),
        ),
      ],
      onSubmit: (sheetContext) async {
        if (nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(
              content: Text('Land name is required'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

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
          name: nameController.text.trim(),
          size: double.tryParse(sizeController.text.trim()),
          location: locationController.text.trim().isEmpty
              ? null
              : locationController.text.trim(),
          soilType: soilTypeController.text.trim().isEmpty
              ? null
              : soilTypeController.text.trim(),
        );
        context.read<LandBloc>().add(AddLandEvent(land));
        Navigator.pop(sheetContext);
      },
    );
  }

  void _showEditLandDialog(Land land) {
    final nameController = TextEditingController(text: land.name);
    final sizeController = TextEditingController(
      text: land.size?.toString() ?? '',
    );
    final locationController = TextEditingController(text: land.location ?? '');
    final soilTypeController = TextEditingController(text: land.soilType ?? '');

    EntityFormSheet.show(
      context: context,
      title: 'Edit Land',
      heightFactor: 0.6,
      submitLabel: 'Update Land',
      fields: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Land Name *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: sizeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Size (Acres)',
            border: OutlineInputBorder(),
            hintText: 'Enter land size in acres',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: locationController,
          decoration: const InputDecoration(
            labelText: 'Location',
            border: OutlineInputBorder(),
            hintText: 'Enter land location (optional)',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: soilTypeController,
          decoration: const InputDecoration(
            labelText: 'Soil Type',
            border: OutlineInputBorder(),
            hintText: 'Enter soil type (optional)',
          ),
        ),
      ],
      onSubmit: (sheetContext) async {
        if (nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(
              content: Text('Land name is required'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final updatedLand = LandModel(
          id: land.id,
          userId: land.userId,
          name: nameController.text.trim(),
          size: double.tryParse(sizeController.text.trim()),
          location: locationController.text.trim().isEmpty
              ? null
              : locationController.text.trim(),
          soilType: soilTypeController.text.trim().isEmpty
              ? null
              : soilTypeController.text.trim(),
          createdAt: land.createdAt,
          updatedAt: DateTime.now(),
        );
        context.read<LandBloc>().add(UpdateLandEvent(updatedLand));
        Navigator.pop(sheetContext);
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(
            content: Text('Land updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${land.name} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
