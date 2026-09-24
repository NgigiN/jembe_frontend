import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:flutter/material.dart';

/// A loading placeholder block (DESIGN_SPEC §6): rounded `container`,
/// pulsing 0.55↔1 over 1.6s.
///
/// The console never shows a centred spinner. Skeletons go in the real
/// layout, so the page doesn't jump when the data lands and you can see
/// what is about to arrive.
class Skeleton extends StatefulWidget {
  const Skeleton({
    this.width,
    this.height = 12,
    this.radius = 6,
    super.key,
  });

  /// A round placeholder, for an avatar slot.
  const Skeleton.circle({double size = 22, Key? key})
    : this(width: size, height: size, radius: size / 2, key: key);

  /// Null means "as wide as the slot allows".
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.55,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.console.container,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A run of skeleton rows sized like table rows, for the table area of a
/// page that is still loading.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({this.count = 6, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
            child: Row(
              children: [
                const Skeleton(width: 52),
                const SizedBox(width: 18),
                // Staggered widths so the block reads as a table of
                // varying labels rather than a barcode.
                Expanded(flex: 3, child: Skeleton(width: i.isEven ? 180 : 140)),
                const SizedBox(width: 18),
                const Expanded(child: Skeleton(width: 70)),
                const SizedBox(width: 18),
                const Skeleton(width: 64),
              ],
            ),
          ),
      ],
    );
  }
}
