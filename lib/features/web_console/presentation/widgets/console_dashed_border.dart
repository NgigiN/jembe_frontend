import 'package:flutter/material.dart';

/// A dashed rounded rectangle (use a radius of half the size for a circle).
///
/// Flutter's [BorderSide] has no dash pattern, and the console needs one in
/// exactly two places: the empty state's zeroed count tiles, and the
/// pending-invitation avatar — both saying "this is a placeholder for
/// something that isn't there yet".
class DashedRoundedBorder extends OutlinedBorder {
  const DashedRoundedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(1);

  @override
  ShapeBorder scale(double t) =>
      DashedRoundedBorder(color: color, radius: radius * t);

  @override
  OutlinedBorder copyWith({BorderSide? side}) => this;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(radius)),
    );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

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
