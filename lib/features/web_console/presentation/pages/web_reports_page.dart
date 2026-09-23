import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/utils/kes.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_year.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/web_console/presentation/utils/csv_download.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_card.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_controls.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_empty.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_rail.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_skeleton.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_table.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_text.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/monthly_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reports (DESIGN_SPEC §4, screen 04): three tabs over the same farm's
/// figures, with the money position and the year's shape in the rail.
///
/// Farm-wide only: the web DI container registers neither LandBloc nor
/// HerdBloc, so the per-enterprise scoping the mobile analytics pages offer
/// has nothing to populate a picker from here.
class WebReportsPage extends StatefulWidget {
  const WebReportsPage({super.key, this.onExportCsv = downloadCsv});

  /// Injected so widget tests can fake the browser download without a real
  /// DOM. Defaults to the real [downloadCsv].
  final void Function(String filename, String csvContent) onExportCsv;

  @override
  State<WebReportsPage> createState() => _WebReportsPageState();
}

class _WebReportsPageState extends State<WebReportsPage> {
  int _tab = 0;
  late final FarmYear _year = FarmYear.containing(DateTime.now(), 1);

  @override
  void initState() {
    super.initState();
    // No fiscal-year picker on the console: a farm-configured fiscal start
    // is a mobile-only concept this page doesn't otherwise consume, so the
    // current calendar year is the sensible default.
    context.read<AnalysisBloc>()
      ..add(const LoadTotalCostsBySeason())
      ..add(const LoadCostBreakdown())
      ..add(LoadAnnualCostSummary(_year.start, _year.end));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AnalysisBloc>().state;
    final farmState = context.watch<FarmBloc>().state;

    return ReportsView(
      farmName: _farmName(farmState),
      year: _year.start.year,
      details: state.detailedCosts.data?.details,
      detailsError: state.detailedCosts.error,
      breakdowns: state.breakdowns.data,
      summaries: state.summaries.data,
      tabIndex: _tab,
      onTabChanged: (index) => setState(() => _tab = index),
      onExportCsv: widget.onExportCsv,
      onRetry: () =>
          context.read<AnalysisBloc>().add(const LoadTotalCostsBySeason()),
    );
  }

  String _farmName(FarmState state) {
    if (state is! FarmLoaded || state.currentFarmId == null) return 'Reports';
    for (final farm in state.farms) {
      if (farm.id == state.currentFarmId) return farm.name;
    }
    return 'Reports';
  }
}

/// The Reports page's drawing, with no bloc in sight.
class ReportsView extends StatelessWidget {
  const ReportsView({
    required this.farmName,
    required this.year,
    required this.details,
    required this.breakdowns,
    required this.summaries,
    this.detailsError,
    this.tabIndex = 0,
    this.onTabChanged,
    this.onExportCsv,
    this.onRetry,
    super.key,
  });

  final String farmName;
  final int year;

  /// Null while loading.
  final List<CostDetail>? details;
  final List<CostBreakdown>? breakdowns;
  final List<MonthlySummary>? summaries;

  final String? detailsError;
  final int tabIndex;
  final ValueChanged<int>? onTabChanged;
  final void Function(String filename, String csvContent)? onExportCsv;
  final VoidCallback? onRetry;

  static const _tabs = ['Cost details', 'Cost breakdown', 'Annual summary'];

  @override
  Widget build(BuildContext context) {
    if (detailsError != null && details == null) {
      return ConsoleErrorState(
        farmName: farmName,
        subtitle: 'Reports',
        detail: detailsError!,
        onRetry: onRetry,
      );
    }

    final rows = details ?? const <CostDetail>[];

    return ConsolePage(
      title: 'Reports',
        subtitle: 'Costs, revenue and profit for $farmName',
      actions: [
        ConsoleButton.outlined(
          label: 'Export CSV',
          icon: Icons.download_outlined,
          onPressed: rows.isEmpty || onExportCsv == null
              ? null
              : () => onExportCsv!(
                  '${farmName.toLowerCase()}-costs.csv',
                  costDetailsToCsv(rows),
                ),
        ),
      ],
      rail: ConsoleRail(
        children: [
          _RailTotals(summaries: summaries, details: details),
          _BreakdownBars(breakdowns: breakdowns),
          ConsoleCard(
            kicker: 'Monthly, $year',
            child: summaries == null
                ? const Skeleton(height: 140, radius: 8)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonthlyBarChart(months: summaries!),
                      const SizedBox(height: 14),
                      _MonthlyTable(months: summaries!),
                    ],
                  ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConsoleTabs(
            labels: _tabs,
            selectedIndex: tabIndex,
            onSelected: onTabChanged ?? (_) {},
          ),
          const SizedBox(height: 12),
          ConsoleCard(
            title: _tabs[tabIndex],
            titleTrailing: Text(
              _cardMeta(tabIndex),
              style: AppTypography.meta.copyWith(color: context.console.muted),
            ),
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
            child: switch (tabIndex) {
              1 => _BreakdownTable(breakdowns: breakdowns),
              2 => _SummaryTable(summaries: summaries),
              _ => _DetailsTable(details: details),
            },
          ),
        ],
      ),
    );
  }

  String _cardMeta(int tab) {
    return switch (tab) {
      1 => '${breakdowns?.length ?? 0} categories',
      2 => '${summaries?.length ?? 0} months',
      _ => '${details?.length ?? 0} sources \u00b7 farm-wide',
    };
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.details});

  final List<CostDetail>? details;

  @override
  Widget build(BuildContext context) {
    if (details == null) return const SkeletonRows(count: 7);
    if (details!.isEmpty) {
      return const ConsoleEmptyBlock(
        icon: Icons.receipt_long_outlined,
        title: 'No costs recorded',
        body: 'Inputs and activities logged against a season or herd add up '
            'here.',
      );
    }

    final total = details!.fold<double>(0, (sum, d) => sum + d.totalCost);

    return ConsoleTable(
      columns: const [
        ConsoleColumn('Source', flex: 4),
        ConsoleColumn('Category', flex: 2),
        ConsoleColumn('Applied to', flex: 3),
        ConsoleColumn('Inputs', flex: 2, alignEnd: true),
        ConsoleColumn('Activities', flex: 2, alignEnd: true),
        ConsoleColumn('Total', flex: 2, alignEnd: true),
      ],
      rows: [
        for (final detail in details!)
          ConsoleRow([
            EntryCell(
              icon: detail.type == 'animal'
                  ? Icons.pets_outlined
                  : Icons.local_florist_outlined,
              label: detail.name,
              category: detail.type == 'animal'
                  ? EntryCategory.animal
                  : EntryCategory.plant,
            ),
            Text(detail.category),
            Text(
              detail.location.isEmpty ? '—' : detail.location,
              style: AppTypography.cell.copyWith(
                color: context.console.onSurface2,
              ),
            ),
            MoneyText(detail.inputCost),
            MoneyText(detail.activityCost),
            MoneyText(detail.totalCost),
          ]),
        // The season total closes the table rather than floating beside it,
        // which is where the eye is already looking after the last row.
        ConsoleRow(
          [
            Text(
              'Season total',
              style: AppTypography.cellStrong.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            MoneyText(total),
          ],
          emphasised: true,
          tint: context.console.surfaceLow,
        ),
      ],
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({required this.breakdowns});

  final List<CostBreakdown>? breakdowns;

  @override
  Widget build(BuildContext context) {
    if (breakdowns == null) return const SkeletonRows();
    if (breakdowns!.isEmpty) {
      return const ConsoleEmptyBlock(
        icon: Icons.donut_small_outlined,
        title: 'No breakdown yet',
        body: 'Once inputs are logged, this shows where the money went.',
      );
    }

    return ConsoleTable(
      columns: const [
        ConsoleColumn('Category', flex: 3),
        ConsoleColumn('Origin', flex: 3),
        ConsoleColumn('Type', flex: 2),
        ConsoleColumn('Cost', flex: 2, alignEnd: true),
        ConsoleColumn('Share', width: 84, alignEnd: true),
      ],
      rows: [
        for (final row in breakdowns!)
          ConsoleRow([
            EntryCell(
              icon: row.type == 'animal'
                  ? Icons.pets_outlined
                  : Icons.local_florist_outlined,
              label: row.category,
              category: row.type == 'animal'
                  ? EntryCategory.animal
                  : EntryCategory.plant,
            ),
            Text(row.origin),
            Text(
              row.type == 'animal' ? 'Animal' : 'Plant',
              style: AppTypography.cell.copyWith(
                color: context.console.onSurface2,
              ),
            ),
            MoneyText(row.totalCost),
            Text(
              '${row.percentage.toStringAsFixed(1)}%',
              style: AppTypography.cell.copyWith(
                color: context.console.onSurface2,
              ),
            ),
          ]),
      ],
    );
  }
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.summaries});

  final List<MonthlySummary>? summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries == null) return const SkeletonRows();
    if (summaries!.isEmpty) {
      return const ConsoleEmptyBlock(
        icon: Icons.calendar_month_outlined,
        title: 'No months to summarise',
        body: 'This fills in as costs and sales are logged through the year.',
      );
    }

    return ConsoleTable(
      columns: const [
        ConsoleColumn('Month', flex: 2),
        ConsoleColumn('Costs', flex: 2, alignEnd: true),
        ConsoleColumn('Revenue', flex: 2, alignEnd: true),
        ConsoleColumn('Profit', flex: 2, alignEnd: true),
      ],
      rows: [
        for (final month in summaries!)
          ConsoleRow([
            Text(month.month),
            MoneyText(month.totalCosts),
            MoneyText(month.totalRevenue, tone: MoneyTone.positive),
            MoneyText(month.profit, tone: MoneyTone.bySign),
          ]),
      ],
    );
  }
}

class _RailTotals extends StatelessWidget {
  const _RailTotals({required this.summaries, required this.details});

  final List<MonthlySummary>? summaries;
  final List<CostDetail>? details;

  @override
  Widget build(BuildContext context) {
    // The year's months are the only place the console can see revenue as
    // well as costs, so the rail's totals come from there. Before they
    // land, the cost side is still worth showing on its own.
    final costs =
        summaries?.fold<double>(0, (sum, m) => sum + m.totalCosts) ??
        details?.fold<double>(0, (sum, d) => sum + d.totalCost) ??
        0;
    final revenue =
        summaries?.fold<double>(0, (sum, m) => sum + m.totalRevenue) ?? 0;

    return TotalsStack(
      costs: costs,
      revenue: revenue,
      muted: summaries == null && details == null,
    );
  }
}

class _BreakdownBars extends StatelessWidget {
  const _BreakdownBars({required this.breakdowns});

  final List<CostBreakdown>? breakdowns;

  @override
  Widget build(BuildContext context) {
    if (breakdowns == null) {
      return const ConsoleCard(
        kicker: 'Cost breakdown \u00b7 by input type',
        child: Column(
          children: [
            Skeleton(height: 28),
            SizedBox(height: 12),
            Skeleton(height: 28),
          ],
        ),
      );
    }

    final byCategory = <String, double>{};
    for (final row in breakdowns!) {
      byCategory[row.category] = (byCategory[row.category] ?? 0) + row.totalCost;
    }
    final total = byCategory.values.fold<double>(0, (sum, v) => sum + v);
    final ranked = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = ranked.take(5).toList();

    if (shown.isEmpty || total == 0) {
      return ConsoleCard(
        kicker: 'Cost breakdown \u00b7 by input type',
        child: Text(
          'No costs logged yet.',
          style: AppTypography.bodyDense.copyWith(color: context.console.muted),
        ),
      );
    }

    return ConsoleCard(
      kicker: 'Cost breakdown \u00b7 by input type',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            ConsoleBarMeter(
              label: shown[i].key,
              fraction: shown[i].value / total,
              trailing:
                  '${formatKes(shown[i].value)} · '
                  '${(shown[i].value / total * 100).round()}%',
            ),
          ],
        ],
      ),
    );
  }
}

/// The Export CSV payload. Public so a test can assert on it without
/// driving the button.
String costDetailsToCsv(List<CostDetail> details) {
  final buffer = StringBuffer()
    ..writeln('Type,Name,Category,Location,Input Cost,Activity Cost,Total Cost');
  for (final d in details) {
    buffer.writeln(
      [
        _csvField(d.type),
        _csvField(d.name),
        _csvField(d.category),
        _csvField(d.location),
        d.inputCost,
        d.activityCost,
        d.totalCost,
      ].join(','),
    );
  }
  return buffer.toString();
}

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// The rail's month-by-month table under the chart (DESIGN_SPEC §4): 12px
/// rows, profit coloured by sign.
class _MonthlyTable extends StatelessWidget {
  const _MonthlyTable({required this.months});

  final List<MonthlySummary> months;

  @override
  Widget build(BuildContext context) {
    return ConsoleTable(
      columns: const [
        ConsoleColumn('Month', flex: 3),
        ConsoleColumn('Costs', flex: 3, alignEnd: true),
        ConsoleColumn('Revenue', flex: 3, alignEnd: true),
        ConsoleColumn('Profit', flex: 3, alignEnd: true),
      ],
      rows: [
        for (final month in months)
          ConsoleRow([
            Text(month.month, style: AppTypography.meta),
            MoneyText(month.totalCosts, size: 13),
            MoneyText(month.totalRevenue, size: 13),
            MoneyText(month.profit, size: 13, tone: MoneyTone.bySign, signed: true),
          ]),
      ],
    );
  }
}
