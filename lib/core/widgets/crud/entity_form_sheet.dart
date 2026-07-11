import 'package:flutter/material.dart';

class EntityFormSheet {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<Widget> fields,
    required String submitLabel,
    required void Function(BuildContext sheetContext) onSubmit,
    GlobalKey<FormState>? formKey,
    AutovalidateMode autovalidateMode = AutovalidateMode.disabled,
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
                  child: formKey == null
                      ? Column(children: fields)
                      : Form(
                          key: formKey,
                          autovalidateMode: autovalidateMode,
                          child: Column(children: fields),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey != null &&
                        !(formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    onSubmit(sheetContext);
                  },
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
    final systemPadding = MediaQuery.paddingOf(context);
    final availableHeight = MediaQuery.sizeOf(context).height -
        viewInsets.bottom -
        systemPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: viewInsets.bottom + systemPadding.bottom,
      ),
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
