import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:flutter/material.dart';

/// Which way a sorted column points, or [none] for a column that isn't
/// the sort key.
enum SortDirection { none, ascending, descending }

/// One column of a [ConsoleTable].
///
/// Widths are either a [flex] share of the leftover space or a fixed
/// [width]; giving both is a mistake the assert catches.
class ConsoleColumn {
  const ConsoleColumn(
    this.label, {
    this.flex = 1,
    this.width,
    this.alignEnd = false,
    this.sort = SortDirection.none,
    this.onSort,
  }) : assert(
         width == null || flex == 1,
         'A fixed-width column ignores flex — set one or the other',
       );

  /// Rendered as an 11px uppercase header cell.
  final String label;

  final int flex;
  final double? width;

  /// Right-aligns header and cells. Amount columns do this (DESIGN_SPEC §3).
  final bool alignEnd;

  final SortDirection sort;
  final VoidCallback? onSort;
}

/// One row of a [ConsoleTable] — either a row of cells, or a full-width
/// day-group label ("TODAY · 23 SEP") in the Feed.
class ConsoleRow {
  const ConsoleRow(this.cells, {this.tint, this.onTap, this.emphasised = false})
    : group = null;

  /// A full-width group heading (DESIGN_SPEC §3, "Day-group rows").
  const ConsoleRow.group(String label)
    : group = label,
      cells = const [],
      tint = null,
      onTap = null,
      emphasised = false;

  final List<Widget> cells;
  final String? group;

  /// Tints the row — `surfaceLow` for a pending invitation or the current
  /// farm (DESIGN_SPEC §4).
  final Color? tint;

  final VoidCallback? onTap;

  /// A summary row such as "Season total": no bottom border, and it sits
  /// above the pager rather than among the data.
  final bool emphasised;
}

/// The console's table (DESIGN_SPEC §3), shared by Dashboard, Feed,
/// Reports, Members and Farms.
///
/// Built from [Row]s rather than Material's [DataTable] because every one
/// of those pages needs something DataTable will not give: per-row tinting,
/// full-width group headings interleaved with data rows, and a hover state
/// that covers the whole row. Laying the columns out by hand is less code
/// than fighting for those three.
class ConsoleTable extends StatelessWidget {
  const ConsoleTable({
    required this.columns,
    required this.rows,
    this.footer,
    this.dense = false,
    super.key,
  });

  final List<ConsoleColumn> columns;
  final List<ConsoleRow> rows;

  /// Tighter cell padding, for a table in the 320px rail where the default
  /// 10px gutters would wrap an eight-letter header.
  final bool dense;

  /// The pager strip, drawn below the last row without a separator.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderRow(columns: columns, dense: dense),
        // No keys: rows are positional and are rebuilt wholesale on every
        // data change, so the default position-plus-type matching is what
        // keeps a hovered row hovered across a rebuild.
        for (final row in rows)
          _DataRow(columns: columns, row: row, dense: dense),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DefaultTextStyle.merge(
              style: AppTypography.meta.copyWith(color: context.console.muted),
              child: footer!,
            ),
          ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.dense});

  final List<ConsoleColumn> columns;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: console.outline)),
      ),
      child: Row(
        children: [
          for (final column in columns)
            _columnSlot(
              column,
              Padding(
                padding: dense
                    ? const EdgeInsets.symmetric(vertical: 8, horizontal: 4)
                    : ConsoleMetrics.tableHeaderPadding,
                child: _HeaderCell(column: column, scheme: scheme),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.column, required this.scheme});

  final ConsoleColumn column;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final sorted = column.sort != SortDirection.none;
    final label = Text(
      column.label.toUpperCase(),
      style: AppTypography.kicker.copyWith(
        // The sorted column's header darkens to onSurface — that plus the
        // arrow is how §3 says which column the rows are ordered by.
        color: sorted ? scheme.onSurface : context.console.muted,
      ),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: column.alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(child: label),
        if (sorted) ...[
          const SizedBox(width: 4),
          Icon(
            column.sort == SortDirection.ascending
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            size: 13,
            color: scheme.primary,
          ),
        ],
      ],
    );

    if (column.onSort == null) return content;
    return InkWell(
      onTap: column.onSort,
      borderRadius: BorderRadius.circular(4),
      child: content,
    );
  }
}

class _DataRow extends StatefulWidget {
  const _DataRow({
    required this.columns,
    required this.row,
    required this.dense,
  });

  final List<ConsoleColumn> columns;
  final ConsoleRow row;
  final bool dense;

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final row = widget.row;

    if (row.group != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6, left: 10),
        child: Text(
          row.group!.toUpperCase(),
          style: AppTypography.kicker.copyWith(color: console.muted),
        ),
      );
    }

    final background = row.tint ?? (_hovered ? console.surfaceLow : null);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: row.emphasised
            ? null
            : Border(bottom: BorderSide(color: console.outline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            _columnSlot(
              widget.columns[i],
              Padding(
                padding: widget.dense
                    ? const EdgeInsets.symmetric(vertical: 9, horizontal: 4)
                    : ConsoleMetrics.tableCellPadding,
                child: DefaultTextStyle.merge(
                  style: AppTypography.cell.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Align(
                    alignment: widget.columns[i].alignEnd
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: i < row.cells.length
                        ? row.cells[i]
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Hover is only meaningful where the row does something; a static
    // row that lights up under the pointer promises a click it hasn't got.
    if (row.onTap == null) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(onTap: row.onTap, child: content),
    );
  }
}

Widget _columnSlot(ConsoleColumn column, Widget child) {
  if (column.width != null) {
    return SizedBox(width: column.width, child: child);
  }
  return Expanded(flex: column.flex, child: child);
}

/// The table's "Entry" cell (DESIGN_SPEC §3): an 18px icon coloured by
/// category, then the label at 13px/500.
class EntryCell extends StatelessWidget {
  const EntryCell({
    required this.icon,
    required this.label,
    this.category = EntryCategory.money,
    super.key,
  });

  final IconData icon;
  final String label;
  final EntryCategory category;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final color = switch (category) {
      EntryCategory.plant => console.plant,
      EntryCategory.animal => console.animal,
      EntryCategory.money => console.onSurface2,
    };

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTypography.cellStrong)),
      ],
    );
  }
}

/// What an entry is about, which is what colours its icon (DESIGN_SPEC §3).
enum EntryCategory { plant, animal, money }

/// The "Logged by" cell: a 22px initials avatar and the person's name.
class LoggedByCell extends StatelessWidget {
  const LoggedByCell(this.name, {this.avatar, super.key});

  final String name;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) {
      return Text('—', style: TextStyle(color: context.console.muted));
    }
    return Row(
      children: [
        if (avatar != null) ...[avatar!, const SizedBox(width: 8)],
        Expanded(child: Text(name, style: AppTypography.cell)),
      ],
    );
  }
}
