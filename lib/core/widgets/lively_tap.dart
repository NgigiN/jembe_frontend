import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps [child] with a subtle press-down scale and a light haptic tick,
/// without interfering with any tap/ripple handling [child] already has
/// (EntityCard's InkWell, ContentCard's ListTile, etc.). Listens to raw
/// pointer events via [Listener], which sits outside Flutter's gesture
/// arena entirely, rather than competing with the child's own gesture
/// recognizer for the tap.
class LivelyTap extends StatefulWidget {
  const LivelyTap({required this.child, this.enabled = true, super.key});

  final Widget child;

  /// When false, renders [child] directly with no scale/haptic effect - for
  /// sites where the wrapped control can itself be disabled (e.g. a locked
  /// setup step).
  final bool enabled;

  @override
  State<LivelyTap> createState() => _LivelyTapState();
}

class _LivelyTapState extends State<LivelyTap>
    with SingleTickerProviderStateMixin {
  static const _downDuration = Duration(milliseconds: 100);
  static const _upDuration = Duration(milliseconds: 150);

  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _downDuration);
    _scale = Tween<double>(
      begin: 1,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Listener(
      // Without this, Listener only fires when a descendant independently
      // reports a hit (e.g. an InkWell) - opaque means it always counts
      // itself as hit, without blocking the child's own gesture handling.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        HapticFeedback.selectionClick();
        _controller.duration = _downDuration;
        _controller.forward();
      },
      onPointerUp: (_) {
        _controller.duration = _upDuration;
        _controller.reverse();
      },
      onPointerCancel: (_) {
        _controller.duration = _upDuration;
        _controller.reverse();
      },
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
