import 'package:flutter/material.dart';

class EntityErrorView extends StatelessWidget {
  const EntityErrorView({
    required this.message,
    required this.onRetry,
    this.isNetworkError = false,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isNetworkError;

  @override
  Widget build(BuildContext context) {
    final color = isNetworkError
        ? const Color(0xFFE65100)
        : Theme.of(context).colorScheme.error;
    final icon = isNetworkError ? Icons.wifi_off_outlined : Icons.error_outline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: color.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
