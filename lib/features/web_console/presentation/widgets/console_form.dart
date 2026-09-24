import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/core/utils/console_dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A labelled form row: a 12px muted label over its control.
///
/// The console labels above rather than inside its fields — a floating
/// label that becomes the field's own content is fine on a phone where
/// vertical space is scarce, and needless on a form this wide.
class ConsoleField extends StatelessWidget {
  const ConsoleField({
    required this.label,
    required this.child,
    this.hint,
    super.key,
  });

  final String label;
  final Widget child;

  /// A line under the control, for the thing the label can't say.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.meta.copyWith(color: console.muted),
        ),
        const SizedBox(height: 5),
        child,
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(
            hint!,
            style: AppTypography.meta.copyWith(color: console.muted),
          ),
        ],
      ],
    );
  }
}

/// A plain text field at the console's density.
class ConsoleTextField extends StatelessWidget {
  const ConsoleTextField({
    required this.controller,
    this.hintText,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.autofocus = false,
    this.prefix,
    this.onChanged,
    super.key,
  });

  /// A field for money or a quantity: numeric keyboard, and the formatter
  /// that stops a second decimal point being typed.
  const ConsoleTextField.number({
    required this.controller,
    this.hintText,
    this.validator,
    this.prefix,
    this.onChanged,
    this.autofocus = false,
    super.key,
  }) : maxLines = 1,
       keyboardType = const TextInputType.numberWithOptions(decimal: true),
       inputFormatters = const [_DecimalFormatter()];

  final TextEditingController controller;
  final String? hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool autofocus;
  final String? prefix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      autofocus: autofocus,
      onChanged: onChanged,
      style: AppTypography.bodyDense,
      decoration: InputDecoration(
        hintText: hintText,
        prefixText: prefix,
        prefixStyle: AppTypography.bodyDense.copyWith(
          color: context.console.muted,
        ),
      ),
    );
  }
}

/// Accepts digits and at most one decimal point. Written out rather than
/// using a regex formatter so an empty field and a lone "." both stay
/// typeable on the way to a real number.
class _DecimalFormatter extends TextInputFormatter {
  const _DecimalFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (RegExp(r'^\d*\.?\d*$').hasMatch(text)) return newValue;
    return oldValue;
  }
}

/// A picker over a fixed list, at the console's density.
class ConsoleFormDropdown<T> extends StatelessWidget {
  const ConsoleFormDropdown({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.hintText,
    this.validator,
    super.key,
  });

  final T? value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;
  final String? hintText;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      validator: validator,
      onChanged: onChanged,
      icon: Icon(Icons.expand_more, size: 18, color: console.muted),
      style: AppTypography.bodyDense.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      hint: hintText == null
          ? null
          : Text(
              hintText!,
              style: AppTypography.bodyDense.copyWith(color: console.muted),
            ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(labelBuilder(item), overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}

/// A text field that suggests from a list without being limited to it —
/// the farm's own cost categories, with room to type a new one.
class ConsoleSuggestField extends StatelessWidget {
  const ConsoleSuggestField({
    required this.controller,
    required this.suggestions,
    this.hintText,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String? hintText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return ConsoleTextField(
        controller: controller,
        hintText: hintText,
        validator: validator,
      );
    }

    return Row(
      children: [
        Expanded(
          child: ConsoleTextField(
            controller: controller,
            hintText: hintText,
            validator: validator,
          ),
        ),
        const SizedBox(width: 6),
        // A menu rather than an inline dropdown: the field is the control,
        // and this only saves you typing a type you already use.
        PopupMenuButton<String>(
          tooltip: 'Pick a type you already use',
          position: PopupMenuPosition.under,
          icon: Icon(
            Icons.arrow_drop_down_circle_outlined,
            size: 20,
            color: context.console.muted,
          ),
          onSelected: (value) => controller.text = value,
          itemBuilder: (context) => [
            for (final suggestion in suggestions)
              PopupMenuItem<String>(
                value: suggestion,
                child: Text(suggestion, style: AppTypography.bodyDense),
              ),
          ],
        ),
      ],
    );
  }
}

/// A date field that opens the platform picker. Shown as "23 Sep 2026"
/// because that is unambiguous; a bare 09/10 is not.
class ConsoleDateField extends StatelessWidget {
  const ConsoleDateField({
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    super.key,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate ?? DateTime(now.year - 5),
          // No future dates: you are recording what happened, and a
          // mistyped year is the most common way a log goes wrong.
          lastDate: lastDate ?? now,
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
          border: Border.all(color: console.outline),
          color: scheme.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${formatDayMonth(value)} ${value.year}',
                style: AppTypography.bodyDense,
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 16, color: console.muted),
          ],
        ),
      ),
    );
  }
}

/// A two-or-more option segmented control — "Plant / Animal",
/// "Birth / Fatality".
class ConsoleSegment<T> extends StatelessWidget {
  const ConsoleSegment({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final console = context.console;

    return Row(
      children: [
        for (final (option, label) in options) ...[
          if (option != options.first.$1) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: option == value
                  ? scheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                ConsoleMetrics.radiusSmallButton,
              ),
              child: InkWell(
                onTap: () => onChanged(option),
                borderRadius: BorderRadius.circular(
                  ConsoleMetrics.radiusSmallButton,
                ),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      ConsoleMetrics.radiusSmallButton,
                    ),
                    border: Border.all(
                      color: option == value
                          ? Colors.transparent
                          : console.outline,
                    ),
                  ),
                  child: Text(
                    label,
                    style: AppTypography.bodyDense.copyWith(
                      fontWeight: FontWeight.w500,
                      color: option == value
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Two fields side by side above 420px, stacked below it.
class ConsoleFieldRow extends StatelessWidget {
  const ConsoleFieldRow({required this.left, required this.right, super.key});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [left, const SizedBox(height: 14), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

/// Required-field messages in the console's voice (DESIGN_SPEC §7): plain,
/// second person, sentence case, no exclamation marks.
String? requiredText(String? value, String what) {
  if (value == null || value.trim().isEmpty) return 'Add the $what.';
  return null;
}

String? requiredAmount(String? value, String what) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Add the $what.';
  final parsed = double.tryParse(text);
  if (parsed == null) return 'That is not a number.';
  if (parsed < 0) return "A $what can't be negative.";
  return null;
}

String? requiredCount(String? value, String what) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Add the $what.';
  final parsed = int.tryParse(text);
  if (parsed == null) return 'Use a whole number.';
  if (parsed <= 0) return 'Use a number above zero.';
  return null;
}
