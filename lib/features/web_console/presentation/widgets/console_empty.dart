import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:flutter/material.dart';

/// A quiet "nothing here" block that sits inside a card where a table
/// would be (DESIGN_SPEC §6).
class ConsoleEmptyBlock extends StatelessWidget {
  const ConsoleEmptyBlock({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 28, color: console.muted),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.cardTitle),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.bodyDense.copyWith(color: console.muted),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// The whole-page error state (DESIGN_SPEC §6, screen 08).
///
/// The page header stays, because losing it too would leave you unsure
/// whether the farm or the whole console had gone. The copy leads with
/// what is still true — nothing was lost — before offering the retry.
class ConsoleErrorState extends StatelessWidget {
  const ConsoleErrorState({
    required this.farmName,
    required this.detail,
    this.subtitle,
    this.onRetry,
    this.onGoToFeed,
    super.key,
  });

  final String farmName;

  /// The underlying failure, shown small and monospaced. It is for
  /// reporting the problem, not for reading.
  final String detail;

  final String? subtitle;
  final VoidCallback? onRetry;
  final VoidCallback? onGoToFeed;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final scheme = Theme.of(context).colorScheme;

    return ConsolePage(
      title: farmName,
      subtitle: subtitle,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: SizedBox(
            width: 440,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: console.negativeContainer,
                    borderRadius: BorderRadius.circular(
                      ConsoleMetrics.radiusCard,
                    ),
                  ),
                  child: Icon(Icons.cloud_off, size: 30, color: scheme.error),
                ),
                const SizedBox(height: 18),
                Text(
                  "Couldn't reach $farmName",
                  style: AppTypography.amount(26).copyWith(
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nothing was lost. The console could not read the farm just '
                  'now — anything logged on Android is still there, and this '
                  'page will fill in once the connection comes back.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyDense.copyWith(
                    color: console.onSurface2,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onRetry != null)
                      ConsoleButton.filled(
                        label: 'Try again',
                        onPressed: onRetry,
                      ),
                    if (onRetry != null && onGoToFeed != null)
                      const SizedBox(width: 8),
                    if (onGoToFeed != null)
                      ConsoleButton.outlined(
                        label: 'Go to Feed',
                        onPressed: onGoToFeed,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: console.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
