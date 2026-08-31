import 'package:flutter/material.dart';

/// A dropdown for selecting an existing [T] from [items], with an inline
/// "add new" button that defers to [onAddNew] (typically an entity's own
/// existing add-dialog) and auto-selects the id it returns.
class EntityPickerWithAdd<T> extends StatelessWidget {
  const EntityPickerWithAdd({
    required this.items,
    required this.selectedId,
    required this.idOf,
    required this.labelOf,
    required this.onChanged,
    required this.labelText,
    required this.onAddNew,
    this.hintText,
    this.validator,
    this.prefixIcon,
    super.key,
  });

  final List<T> items;
  final String? selectedId;
  final String Function(T item) idOf;
  final String Function(T item) labelOf;
  final ValueChanged<String?> onChanged;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final Widget? prefixIcon;
  final Future<String?> Function(BuildContext context) onAddNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              prefixIcon: prefixIcon,
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: idOf(item),
                    child: Text(labelOf(item)),
                  ),
                )
                .toList(),
            validator: validator,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            final newId = await onAddNew(context);
            if (newId != null) onChanged(newId);
          },
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add new',
          style: IconButton.styleFrom(backgroundColor: Colors.green.shade50),
        ),
      ],
    );
  }
}
