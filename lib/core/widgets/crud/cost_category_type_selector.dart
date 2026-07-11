import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CostCategoryTypeSelector extends StatelessWidget {
  const CostCategoryTypeSelector({
    required this.categoryKind,
    required this.sourceType,
    required this.selectedType,
    required this.onTypeChanged,
    required this.labelText,
    this.hintText,
    this.addButtonBackgroundColor,
    this.validator,
    super.key,
  });

  final String categoryKind;
  final String sourceType;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final String labelText;
  final String? hintText;
  final Color? addButtonBackgroundColor;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CostCategoryBloc, CostCategoryState>(
      builder: (context, costCategoryState) {
        final categories = costCategoryState.categories
            .where((category) => category.type == sourceType)
            .toList();

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedType.isEmpty ? null : selectedType,
                decoration: InputDecoration(
                  labelText: labelText,
                  border: const OutlineInputBorder(),
                  hintText: hintText,
                  suffixIcon: costCategoryState is CostCategoryLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                items: _buildDropdownItems(
                  categories.map((category) => category.name),
                  selectedType,
                ),
                validator: validator,
                onChanged: (value) => onTypeChanged(value ?? ''),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () =>
                  _showManageTypesSheet(context, categories: categories),
              icon: const Icon(Icons.tune),
              tooltip: 'Manage custom types',
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
              ),
            ),
            IconButton(
              onPressed: () => _showCreateTypeDialog(context),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add new type',
              style: IconButton.styleFrom(
                backgroundColor:
                    addButtonBackgroundColor ?? Colors.green.shade50,
              ),
            ),
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(
    Iterable<String> categoryNames,
    String selectedName,
  ) {
    final names = List<String>.from(categoryNames);
    if (selectedName.isNotEmpty && !names.contains(selectedName)) {
      names.add(selectedName);
    }

    return names
        .map((name) => DropdownMenuItem<String>(value: name, child: Text(name)))
        .toList();
  }

  void _showCreateTypeDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final typeLabel = categoryKind == 'input' ? 'Input' : 'Activity';
    final sourceLabel = sourceType == 'plant' ? 'Plant' : 'Animal';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add New $sourceLabel $typeLabel Type'),
        content: Form(
          key: formKey,
          child: ValidatedNameField(
            controller: nameController,
            labelText: '$typeLabel Type Name',
            hintText: 'e.g., Custom $typeLabel',
            validator: (value) =>
                requiredName(value, fieldLabel: '$typeLabel type'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;

              final name = sanitizeText(nameController.text);
              context.read<CostCategoryBloc>().add(
                AddCostCategoryEvent(
                  name: name,
                  type: sourceType,
                  category: categoryKind,
                ),
              );
              Navigator.pop(dialogContext);
              onTypeChanged(name);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name added successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManageTypesSheet(
    BuildContext context, {
    required List<CostCategory> categories,
  }) async {
    final customCategories = categories
        .where((category) => !category.isDefault)
        .toList();
    final typeLabel = categoryKind == 'input' ? 'input' : 'activity';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Custom ${typeLabel[0].toUpperCase()}${typeLabel.substring(1)} Types',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Swipe left on a custom type to delete it.',
                style: Theme.of(
                  sheetContext,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              if (customCategories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No custom types yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: customCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final category = customCategories[index];
                      return Dismissible(
                        key: ValueKey(category.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => EntityDeleteDialog.show(
                          context: context,
                          title: 'Delete Type',
                          message:
                              'Delete "${category.name}"? This cannot be undone.',
                        ),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) {
                          context.read<CostCategoryBloc>().add(
                            DeleteCostCategoryEvent(
                              id: category.id,
                              category: categoryKind,
                            ),
                          );
                          if (selectedType == category.name) {
                            onTypeChanged('');
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${category.name} deleted successfully',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: Card(
                          child: ListTile(
                            title: Text(category.name),
                            subtitle: Text(
                              sourceType == 'plant' ? 'Plant' : 'Animal',
                            ),
                            trailing: Icon(
                              Icons.swipe_left,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

