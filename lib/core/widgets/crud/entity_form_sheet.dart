import 'package:flutter/material.dart';

class EntityFormSheet {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<Widget> fields,
    required String submitLabel,
    required void Function(BuildContext sheetContext) onSubmit,
    double heightFactor = 0.8,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => container(
        context: sheetContext,
        heightFactor: heightFactor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: scrollableForm(
                  context: sheetContext,
                  child: Column(children: fields),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onSubmit(sheetContext),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    submitLabel,
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
    );
  }

  /// Wraps bottom-sheet content so it moves up and stays scrollable with the
  /// keyboard.
  static Widget container({
    required BuildContext context,
    required Widget child,
    double heightFactor = 0.8,
  }) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final availableHeight =
        MediaQuery.sizeOf(context).height - viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: availableHeight * heightFactor,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: child,
      ),
    );
  }

  static Widget scrollableForm({
    required BuildContext context,
    required Widget child,
  }) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      child: child,
    );
  }
}
