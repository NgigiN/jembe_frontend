import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_dashed_border.dart';
import 'package:flutter/material.dart';

/// One of the Dashboard's six count tiles (DESIGN_SPEC §4): a 12px muted
/// label with its icon on the right, and the count beneath in Fraunces 26.
///
/// At zero the tile goes quiet — dashed border, outline-coloured figure —
/// which is the empty state's own treatment (§6). It is the same widget
/// rather than a second one because "nothing here yet" is a property of
/// the number, not of the page.
class CountTile extends StatelessWidget {
  const CountTile({
    required this.label,
    required this.count,
    required this.icon,
    super.key,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final empty = count == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: empty
            ? DashedRoundedBorder(
                color: console.outline,
                radius: ConsoleMetrics.radiusCard,
              )
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ConsoleMetrics.radiusCard),
                side: BorderSide(color: console.outline),
              ),
        shadows: empty
            ? null
            : ConsoleMetrics.cardShadow(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.meta.copyWith(color: console.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: console.muted),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: AppTypography.amount(26).copyWith(
              color: empty
                  ? console.outline
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
