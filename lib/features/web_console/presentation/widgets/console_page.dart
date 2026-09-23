import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:flutter/material.dart';

/// The frame every console page is poured into (DESIGN_SPEC §2): a header
/// with title, subtitle and actions, the main column, and the right rail.
///
/// Pages hand over their parts rather than laying this out themselves,
/// which is what keeps the header baseline and the rail's width identical
/// across Dashboard, Feed, Reports, Members and Farms.
class ConsolePage extends StatelessWidget {
  const ConsolePage({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.rail,
    super.key,
  });

  /// Fraunces 24 — usually the farm's name.
  final String title;

  /// 13px muted — "Long rains 2026 · Wednesday 23 September".
  final String? subtitle;

  /// Right of the header, 8px apart, 36px tall.
  final List<Widget> actions;

  final Widget child;

  /// The 320px right column. Stacks under [child] below 1100px.
  final Widget? rail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            rail != null &&
            constraints.maxWidth >= ConsoleMetrics.railStackBreakpoint;

        return SingleChildScrollView(
          padding: ConsoleMetrics.mainPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: title, subtitle: subtitle, actions: actions),
              const SizedBox(height: ConsoleMetrics.gridGap),
              if (sideBySide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: child),
                    const SizedBox(width: ConsoleMetrics.gridGap),
                    SizedBox(width: ConsoleMetrics.railWidth, child: rail),
                  ],
                )
              else ...[
                child,
                if (rail != null) ...[
                  const SizedBox(height: ConsoleMetrics.gridGap),
                  rail!,
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final console = context.console;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTypography.pageTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: AppTypography.bodyDense.copyWith(color: console.muted),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ],
    );
  }
}

/// A rail column: the totals stack, then contextual cards, evenly spaced.
class ConsoleRail extends StatelessWidget {
  const ConsoleRail({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: ConsoleMetrics.gridGap),
          children[i],
        ],
      ],
    );
  }
}

/// A header action button at the console's 36px height. `tonal` is the
/// secondary weight the Dashboard's "Log activity" / "Log input" use;
/// `filled` is the one primary action per header.
class ConsoleButton extends StatelessWidget {
  const ConsoleButton.filled({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _variant = _ButtonVariant.filled;

  const ConsoleButton.tonal({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _variant = _ButtonVariant.tonal;

  const ConsoleButton.outlined({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _variant = _ButtonVariant.outlined;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final _ButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = Text(label);
    final iconWidget = icon == null ? null : Icon(icon, size: 18);

    return switch (_variant) {
      _ButtonVariant.filled => FilledButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: child,
      ),
      _ButtonVariant.tonal => FilledButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: child,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
        ),
      ),
      _ButtonVariant.outlined => OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: child,
      ),
    };
  }
}

enum _ButtonVariant { filled, tonal, outlined }
