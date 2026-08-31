import 'package:flutter/material.dart';

enum StepStatus { completed, available, locked }

class SetupStepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;
  final String? summary;
  final StepStatus status;
  final VoidCallback? onTap;

  const SetupStepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    this.summary,
    this.status = StepStatus.available,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StepStatus.completed => Colors.green,
      StepStatus.available => Theme.of(context).colorScheme.primary,
      StepStatus.locked => Theme.of(context).colorScheme.outline,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: status != StepStatus.locked ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: status == StepStatus.locked
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: status == StepStatus.available
                      ? Border.all(color: color, width: 2)
                      : null,
                ),
                child: Center(
                  child: switch (status) {
                    StepStatus.completed => const Icon(
                        Icons.check,
                        color: Colors.green,
                        size: 20,
                      ),
                    StepStatus.available => Text(
                        '$stepNumber',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    StepStatus.locked => Icon(
                        Icons.lock,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: status == StepStatus.locked
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary ?? subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == StepStatus.available)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
