import 'package:flutter/material.dart';

class TypedDeleteAccountDialog {
  static const confirmationPhrase = 'DELETE';

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) =>
          _TypedDeleteAccountDialogContent(title: title, message: message),
    );
  }
}

class _TypedDeleteAccountDialogContent extends StatefulWidget {
  const _TypedDeleteAccountDialogContent({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  State<_TypedDeleteAccountDialogContent> createState() =>
      _TypedDeleteAccountDialogContentState();
}

class _TypedDeleteAccountDialogContentState
    extends State<_TypedDeleteAccountDialogContent> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final isConfirmed = value == TypedDeleteAccountDialog.confirmationPhrase;
    if (isConfirmed != _isConfirmed) {
      setState(() => _isConfirmed = isConfirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          Text(
            'Type ${TypedDeleteAccountDialog.confirmationPhrase} to confirm.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isConfirmed
              ? () => Navigator.of(context).pop(true)
              : null,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
