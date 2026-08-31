import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:farm_tracker/core/validation/field_limits.dart';
import 'package:farm_tracker/core/validation/input_formatters.dart';

class ValidatedNameField extends StatelessWidget {
  const ValidatedNameField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.prefixIcon,
    this.textCapitalization = TextCapitalization.words,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final Icon? prefixIcon;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
      ),
      validator: validator,
      inputFormatters: nameFormatters(),
      maxLength: FieldLimits.nameMax,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
          null,
      textCapitalization: textCapitalization,
    );
  }
}

class ValidatedLocationField extends StatelessWidget {
  const ValidatedLocationField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final Icon? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
      ),
      validator: validator,
      inputFormatters: locationFormatters(),
      maxLength: FieldLimits.locationMax,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
          null,
      textCapitalization: TextCapitalization.words,
    );
  }
}

class ValidatedDecimalField extends StatelessWidget {
  const ValidatedDecimalField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.prefixIcon,
    this.allowNegative = false,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final Icon? prefixIcon;
  final bool allowNegative;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
      ),
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: decimalFormatters(allowNegative: allowNegative),
    );
  }
}

class ValidatedIntegerField extends StatelessWidget {
  const ValidatedIntegerField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final Icon? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
      ),
      validator: validator,
      keyboardType: TextInputType.number,
      inputFormatters: integerFormatters(),
    );
  }
}

class ValidatedNotesField extends StatelessWidget {
  const ValidatedNotesField({
    super.key,
    required this.controller,
    required this.labelText,
    this.validator,
    this.maxLines = 3,
  });

  final TextEditingController controller;
  final String labelText;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        alignLabelWithHint: true,
      ),
      validator: validator,
      inputFormatters: notesFormatters(),
      maxLength: FieldLimits.notesMax,
      maxLines: maxLines,
    );
  }
}