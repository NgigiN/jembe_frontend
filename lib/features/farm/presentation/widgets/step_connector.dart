import 'package:flutter/material.dart';

class StepConnector extends StatelessWidget {

  const StepConnector({super.key, this.isActive = true});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Center(
        child: SizedBox(
          width: 2,
          child: Container(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}
