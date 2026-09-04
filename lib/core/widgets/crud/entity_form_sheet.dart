import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:flutter/material.dart';

class EntityFormSheet {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<Widget> fields,
    required String submitLabel,
    required Future<bool> Function(BuildContext sheetContext) onSubmit,
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
        child: _EntityFormSheetBody(
          title: title,
          fields: fields,
          submitLabel: submitLabel,
          onSubmit: onSubmit,
          formKey: formKey,
          autovalidateMode: autovalidateMode,
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
    final screenHeight = MediaQuery.sizeOf(context).height;

    // The sheet keeps its normal heightFactor height as the keyboard rises
    // rather than shrinking to fit whatever's left — it only shrinks if the
    // keyboard is tall enough that the normal height would overflow above
    // the top of the screen.
    final heightWithoutKeyboard =
        (screenHeight - systemPadding.bottom) * heightFactor;
    final maxAvailableHeight =
        screenHeight - viewInsets.bottom - systemPadding.bottom;
    final height = heightWithoutKeyboard < maxAvailableHeight
        ? heightWithoutKeyboard
        : maxAvailableHeight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: viewInsets.bottom + systemPadding.bottom,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // Gives any ListTile/InkWell inside child a Material ancestor that
        // paints above this container's own DecoratedBox, so their ink
        // effects aren't swallowed by it.
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    );
  }

  static Widget scrollableForm({
    required BuildContext context,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: child,
    );
  }
}

/// The sheet's interactive body. Stays open until [onSubmit] resolves: while
/// awaiting it shows a spinner and disables the close button; on `true` it
/// plays the success feedback and pops; on `false` it re-enables, leaving the
/// typed data intact.
class _EntityFormSheetBody extends StatefulWidget {
  const _EntityFormSheetBody({
    required this.title,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
    required this.formKey,
    required this.autovalidateMode,
  });

  final String title;
  final List<Widget> fields;
  final String submitLabel;
  final Future<bool> Function(BuildContext sheetContext) onSubmit;
  final GlobalKey<FormState>? formKey;
  final AutovalidateMode autovalidateMode;

  @override
  State<_EntityFormSheetBody> createState() => _EntityFormSheetBodyState();
}

class _EntityFormSheetBodyState extends State<_EntityFormSheetBody> {
  bool _submitting = false;

  Future<void> _handleSubmit() async {
    if (widget.formKey != null &&
        !(widget.formKey!.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final ok = await widget.onSubmit(context);
      if (!mounted) return;
      if (ok) {
        SuccessFeedback.saved(); // centralized: only on confirmed success
        Navigator.pop(context);
        return; // popped — do not fall through to re-enable
      }
      // Stay open and re-enable; controllers keep their text.
      setState(() => _submitting = false);
    } catch (e, st) {
      // A throw from onSubmit (e.g. a closed bloc making firstWhere throw)
      // must never leave the button stuck spinning + the close button
      // disabled. Re-enable, and keep a trace rather than swallowing it.
      if (!mounted) return;
      setState(() => _submitting = false);
      appLogger.logError('EntityFormSheet.onSubmit', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed:
                    _submitting ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: EntityFormSheet.scrollableForm(
              context: context,
              child: widget.formKey == null
                  ? Column(children: widget.fields)
                  : Form(
                      key: widget.formKey,
                      autovalidateMode: widget.autovalidateMode,
                      child: Column(children: widget.fields),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.submitLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
