import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:flutter/material.dart';

/// The Reports rail's grouped bar chart (DESIGN_SPEC §4): costs in
/// `onSurface2` at 55%, revenue in `primary`, over `outline` gridlines.
///
/// Drawn from plain widgets rather than a charting package. Two bars a
/// month over four gridlines is less code here than a dependency's
/// configuration would be, and it inherits the console's tokens for free.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({required this.months, this.height = 140, super.key});

  final List<MonthlySummary> months;
  final double height;

  static const _gridlines = 4;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final scheme = Theme.of(context).colorScheme;

    final peak = months.fold<double>(0, (max, month) {
      final biggest = month.totalCosts > month.totalRevenue
          ? month.totalCosts
          : month.totalRevenue;
      return biggest > max ? biggest : max;
    });

    if (months.isEmpty || peak <= 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No monthly figures yet.',
            style: AppTypography.meta.copyWith(color: console.muted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < _gridlines; i++)
                    Container(height: 1, color: console.outline),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final month in months)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Bar(
                              fraction: month.totalCosts / peak,
                              color: console.onSurface2.withValues(alpha: 0.55),
                            ),
                            const SizedBox(width: 2),
                            _Bar(
                              fraction: month.totalRevenue / peak,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final month in months)
              Expanded(
                child: Text(
                  _shortMonth(month.month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'WorkSans',
                    fontSize: 10,
                    color: console.muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _LegendDot(
              color: console.onSurface2.withValues(alpha: 0.55),
              label: 'Costs',
            ),
            const SizedBox(width: 14),
            _LegendDot(color: scheme.primary, label: 'Revenue'),
          ],
        ),
      ],
    );
  }

  /// The server sends the month as "2026-03" or "March"; either way the
  /// axis has room for three letters.
  static String _shortMonth(String month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final numeric = int.tryParse(month.split('-').last);
    if (numeric != null && numeric >= 1 && numeric <= 12) {
      return names[numeric - 1];
    }
    return month.length <= 3 ? month : month.substring(0, 3);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FractionallySizedBox(
        alignment: Alignment.bottomCenter,
        // A month with a real but tiny figure still gets a visible sliver,
        // so "small" never looks like "none".
        heightFactor: fraction <= 0 ? 0 : fraction.clamp(0.03, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.meta.copyWith(color: context.console.muted),
        ),
      ],
    );
  }
}
