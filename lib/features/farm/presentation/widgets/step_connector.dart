import 'package:flutter/material.dart';

class StepConnector extends StatelessWidget {
  final bool isActive;

  const StepConnector({super.key, this.isActive = true});

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
                : Colors.grey.shade200,
          ),
        ),
      ),
    );
  }
}
