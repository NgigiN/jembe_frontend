import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:flutter/material.dart';

/// The filter-chip row above a table (DESIGN_SPEC §3): the active chip is
/// `primaryContainer`, the rest are outlined with muted text.
///
/// Material's [FilterChip] is not used because its M3 defaults bring a
/// check-mark, a 32px minimum and a tonal background the mockups don't
/// have — overriding all three costs more than drawing the chip.
class ConsoleChips extends StatelessWidget {
  const ConsoleChips({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < labels.length; i++)
          _Chip(
            label: labels[i],
            selected: i == selectedIndex,
            onTap: () => onSelected(i),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final console = context.console;

    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusSmallButton),
        side: BorderSide(
          color: selected ? Colors.transparent : console.outline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusSmallButton),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: AppTypography.meta.copyWith(
              fontWeight: FontWeight.w500,
              color: selected ? scheme.onPrimaryContainer : console.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The table pager (DESIGN_SPEC §3): a count on the left, `‹ 1 2 3 ›` on
/// the right with the current page in `primaryContainer`.
class ConsolePager extends StatelessWidget {
  const ConsolePager({
    required this.summary,
    required this.pageCount,
    required this.currentPage,
    required this.onPageChanged,
    super.key,
  });

  /// "8 of 24 entries · Long rains 2026".
  final String summary;

  final int pageCount;

  /// Zero-based.
  final int currentPage;

  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(summary)),
        if (pageCount > 1) ...[
          _Arrow(
            icon: Icons.chevron_left,
            onTap: currentPage > 0
                ? () => onPageChanged(currentPage - 1)
                : null,
          ),
          for (var i = 0; i < pageCount; i++)
            _PageNumber(
              page: i,
              selected: i == currentPage,
              onTap: () => onPageChanged(i),
            ),
          _Arrow(
            icon: Icons.chevron_right,
            onTap: currentPage < pageCount - 1
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
        ],
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      // A disabled arrow stays in place and fades, so the pager doesn't
      // change width as you walk through the pages.
      color: console.muted,
      disabledColor: console.outline,
    );
  }
}

class _PageNumber extends StatelessWidget {
  const _PageNumber({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final int page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final console = context.console;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusSmallButton),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ConsoleMetrics.radiusSmallButton),
          child: SizedBox(
            width: 26,
            height: 26,
            child: Center(
              child: Text(
                '${page + 1}',
                style: AppTypography.meta.copyWith(
                  fontWeight: FontWeight.w500,
                  color: selected ? scheme.onPrimaryContainer : console.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact dropdown the console's toolbars use — "Everyone ▾",
/// "Season ▾", "All inputs ▾". Outlined, 36px, 13px label.
class ConsoleSelect<T> extends StatelessWidget {
  const ConsoleSelect({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.icon,
    super.key,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Container(
      height: ConsoleMetrics.buttonHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
        border: Border.all(color: console.outline),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
          icon: Icon(Icons.expand_more, size: 18, color: console.muted),
          style: AppTypography.bodyDense.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onChanged: onChanged,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: console.muted),
                      const SizedBox(width: 6),
                    ],
                    Text(labelBuilder(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The Reports page's tab strip (DESIGN_SPEC §4): a 2px primary underline
/// under the active label, nothing else.
///
/// Not Material's [TabBar]: that brings an indicator animation, a ripple
/// and a minimum height the mockups don't have, and it wants a
/// [TabController] the page has no other use for.
class ConsoleTabs extends StatelessWidget {
  const ConsoleTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final console = context.console;

    // Scrollable so the tabs never overflow a narrow page; on a wide one
    // it lays out exactly as a plain Row would.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            InkWell(
              onTap: () => onSelected(i),
              child: Container(
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 9),
                margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 18),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == selectedIndex
                          ? scheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: AppTypography.navItem.copyWith(
                    fontWeight: i == selectedIndex
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: i == selectedIndex
                        ? scheme.onSurface
                        : console.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
