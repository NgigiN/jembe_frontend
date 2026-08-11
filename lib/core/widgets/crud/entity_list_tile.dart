import 'package:flutter/material.dart';

class EntityListTile extends StatelessWidget {
  const EntityListTile({
    required this.leadingIcon,
    required this.title,
    super.key,
    this.leadingBackgroundColor,
    this.leadingIconColor,
    this.subtitleFields = const [],
    this.onTap,
    this.onEdit,
    this.onDelete,
  });
  final IconData leadingIcon;
  final Color? leadingBackgroundColor;
  final Color? leadingIconColor;
  final String title;
  final List<Widget> subtitleFields;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasMenu = onEdit != null || onDelete != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: leadingBackgroundColor ?? Colors.grey.shade200,
          child: Icon(
            leadingIcon,
            color: leadingIconColor ?? Colors.grey.shade700,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: subtitleFields.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: subtitleFields,
              ),
        trailing: hasMenu
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit?.call();
                  } else if (value == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}
