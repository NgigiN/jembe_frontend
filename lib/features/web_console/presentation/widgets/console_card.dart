import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:flutter/material.dart';

/// The console's one container: `surface`, 14px radius, a 1px `outline`
/// border and the single hairline shadow (DESIGN_SPEC §1).
///
/// Material's own [Card] is not used because the console never wants
/// tonal elevation — the border does the separating, and stacking M3's
/// surface tint on top of it reads as a second, muddier border.
class ConsoleCard extends StatelessWidget {
  const ConsoleCard({
    required this.child,
    this.title,
    this.kicker,
    this.titleTrailing,
    this.padding = ConsoleMetrics.cardPadding,
    this.color,
    this.borderColor,
    super.key,
  });

  final Widget child;

  /// Fraunces 17/600 heading — "Season log", "Invite by email".
  final String? title;

  /// 11px uppercase heading, used where the card is a labelled block
  /// rather than a titled one — "COST BREAKDOWN", "SEASON". Ignored when
  /// [title] is also set.
  final String? kicker;

  /// Sits at the far end of the title row: type chips, a link, a menu.
  final Widget? titleTrailing;

  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final heading = _buildHeading(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusCard),
        border: Border.all(color: borderColor ?? console.outline),
        boxShadow: ConsoleMetrics.cardShadow(Theme.of(context).brightness),
      ),
      child: Padding(
        padding: padding,
        child: heading == null
            ? child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [heading, const SizedBox(height: 12), child],
              ),
      ),
    );
  }

  Widget? _buildHeading(BuildContext context) {
    final console = context.console;
    final Widget label;
    if (title != null) {
      label = Text(title!, style: AppTypography.cardTitle);
    } else if (kicker != null) {
      label = Text(
        kicker!.toUpperCase(),
        style: AppTypography.kicker.copyWith(color: console.muted),
      );
    } else if (titleTrailing != null) {
      label = const SizedBox.shrink();
    } else {
      return null;
    }

    if (titleTrailing == null) return label;
    return Row(
      children: [
        Flexible(child: label),
        const SizedBox(width: 12),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: titleTrailing),
        ),
      ],
    );
  }
}
