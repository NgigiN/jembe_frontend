import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_text.dart';
import 'package:flutter/material.dart';

/// The totals stack that opens every page's right rail (DESIGN_SPEC §2):
/// Costs, Revenue, then a tinted Profit row whose sign decides its colour.
///
/// It is the same three numbers on every page on purpose — whatever you
/// are looking at, the farm's money position is in the same corner.
class TotalsStack extends StatelessWidget {
  const TotalsStack({
    required this.costs,
    required this.revenue,
    this.profit,
    this.muted = false,
    super.key,
  });

  final num costs;
  final num revenue;

  /// Defaults to `revenue - costs`. Passed explicitly only where the
  /// server already computed it.
  final num? profit;

  /// Renders every amount in `muted` — the empty state's "KES 0" rail,
  /// which should read as "nothing logged yet", not as a real zero
  /// balance (DESIGN_SPEC §6).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final resolvedProfit = profit ?? (revenue - costs);
    const radius = Radius.circular(ConsoleMetrics.radiusCard);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusCard),
        border: Border.all(color: console.outline),
        boxShadow: ConsoleMetrics.cardShadow(Theme.of(context).brightness),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TotalRow(
            label: 'Costs',
            border: Border(bottom: BorderSide(color: console.outline)),
            child: MoneyText(
              costs,
              size: 18,
              tone: muted ? MoneyTone.muted : MoneyTone.neutral,
            ),
          ),
          _TotalRow(
            label: 'Revenue',
            border: Border(bottom: BorderSide(color: console.outline)),
            child: MoneyText(
              revenue,
              size: 18,
              tone: muted ? MoneyTone.muted : MoneyTone.positive,
            ),
          ),
          _TotalRow(
            label: 'Profit',
            background: console.surfaceLow,
            borderRadius: const BorderRadius.only(
              bottomLeft: radius,
              bottomRight: radius,
            ),
            child: MoneyText(
              resolvedProfit,
              size: 22,
              tone: muted ? MoneyTone.muted : MoneyTone.bySign,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.child,
    this.border,
    this.background,
    this.borderRadius,
  });

  final String label;
  final Widget child;
  final BoxBorder? border;
  final Color? background;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: border,
        borderRadius: borderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyDense.copyWith(
                  color: context.console.onSurface2,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// A labelled 6px meter — the cost-breakdown bars and the season's
/// remaining-days bar (DESIGN_SPEC §4).
class ConsoleBarMeter extends StatelessWidget {
  const ConsoleBarMeter({
    required this.label,
    required this.fraction,
    this.trailing,
    this.color,
    super.key,
  });

  final String label;

  /// 0..1. Clamped, so a server that reports 103% still draws a full bar
  /// rather than overflowing the card.
  final double fraction;

  /// The right-hand figure: "71%", or "KES 6,800 · 43%" on Reports.
  final String? trailing;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final fill = color ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.bodyDense)),
            if (trailing != null)
              Text(
                trailing!,
                style: AppTypography.meta.copyWith(color: console.muted),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: console.container,
              valueColor: AlwaysStoppedAnimation<Color>(fill),
            ),
          ),
        ),
      ],
    );
  }
}
