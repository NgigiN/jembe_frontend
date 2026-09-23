import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
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
            ? _DashedRoundedBorder(
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

/// A dashed rounded rectangle. Flutter's [BorderSide] has no dash pattern,
/// and the empty state's "nothing here yet" tiles are the one place the
/// console needs one.
class _DashedRoundedBorder extends OutlinedBorder {
  const _DashedRoundedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(1);

  @override
  ShapeBorder scale(double t) =>
      _DashedRoundedBorder(color: color, radius: radius * t);

  @override
  OutlinedBorder copyWith({BorderSide? side}) => this;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        rect.deflate(1),
        Radius.circular(radius),
      ),
    );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }
}
