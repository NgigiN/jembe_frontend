import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_year.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/web_console/presentation/utils/csv_download.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Wide-layout web-console consumer of the existing `AnalysisBloc`: tables
/// for the unified cost details and the cost breakdown, plus an "Export CSV"
/// button that downloads the cost details as a CSV file. There is no mobile
/// reports page to mirror one-to-one (mobile splits this across
/// TotalCostsBySeasonPage / CostBreakdownPage / AnnualSummaryPage, each also
/// wired to LandBloc/HerdBloc/ScopeChips for enterprise-level scoping); the
/// web console's DI container (lib/web_injection_container.dart) registers
/// neither LandBloc nor HerdBloc, so this page stays farm-wide and consumes
/// only AnalysisBloc, same as its Interfaces contract says.
class WebReportsPage extends StatefulWidget {
  const WebReportsPage({super.key, this.onExportCsv = downloadCsv});

  /// Injected so widget tests can fake the browser download without a real
  /// DOM. Defaults to the real [downloadCsv].
  final void Function(String filename, String csvContent) onExportCsv;

  @override
  State<WebReportsPage> createState() => _WebReportsPageState();
}

class _WebReportsPageState extends State<WebReportsPage> {
  @override
  void initState() {
    super.initState();
    // No fiscal-year picker on the web console (spec parity note above) —
    // the current calendar year (fiscal start month 1) is a reasonable v1
    // default; a farm-configured fiscal year start is a mobile-only concept
    // this page doesn't otherwise consume.
    final farmYear = FarmYear.containing(DateTime.now(), 1);
    context.read<AnalysisBloc>()
      ..add(const LoadTotalCostsBySeason())
      ..add(const LoadCostBreakdown())
      ..add(LoadAnnualCostSummary(farmYear.start, farmYear.end));
  }

  void _exportCsv(List<CostDetail> details) {
    widget.onExportCsv('cost_report.csv', _costDetailsToCsv(details));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          BlocBuilder<AnalysisBloc, AnalysisState>(
            builder: (context, state) {
              final details = state.detailedCosts.data?.details ?? const [];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: details.isEmpty
                      ? null
                      : () => _exportCsv(details),
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<AnalysisBloc, AnalysisState>(builder: _body),
    );
  }

  Widget _body(BuildContext context, AnalysisState state) {
    final costsSlice = state.detailedCosts;
    if (costsSlice.data == null && costsSlice.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (costsSlice.data == null && costsSlice.error != null) {
      return Center(child: Text(costsSlice.error!));
    }
    final details = costsSlice.data?.details ?? const [];
    final breakdowns = state.breakdowns.data ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cost details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _detailsTable(details),
          const SizedBox(height: 32),
          Text(
            'Cost breakdown by input type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _breakdownTable(breakdowns),
          const SizedBox(height: 32),
          Text(
            'Monthly summary',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _summaryTable(state.summaries.data ?? const []),
        ],
      ),
    );
  }

  Widget _detailsTable(List<CostDetail> details) {
    if (details.isEmpty) {
      return const Text('No cost data for this selection.');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Location')),
          DataColumn(label: Text('Input cost'), numeric: true),
          DataColumn(label: Text('Activity cost'), numeric: true),
          DataColumn(label: Text('Total cost'), numeric: true),
        ],
        rows: [
          for (final d in details)
            DataRow(
              cells: [
                DataCell(Text(d.name)),
                DataCell(Text(d.type)),
                DataCell(Text(d.category)),
                DataCell(Text(d.location)),
                DataCell(Text(d.inputCost.toStringAsFixed(2))),
                DataCell(Text(d.activityCost.toStringAsFixed(2))),
                DataCell(Text(d.totalCost.toStringAsFixed(2))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _breakdownTable(List<CostBreakdown> breakdowns) {
    if (breakdowns.isEmpty) {
      return const Text('No breakdown data for this selection.');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Origin')),
          DataColumn(label: Text('Total cost'), numeric: true),
          DataColumn(label: Text('Percentage'), numeric: true),
        ],
        rows: [
          for (final b in breakdowns)
            DataRow(
              cells: [
                DataCell(Text(b.category)),
                DataCell(Text(b.type)),
                DataCell(Text(b.origin)),
                DataCell(Text(b.totalCost.toStringAsFixed(2))),
                DataCell(Text('${b.percentage.toStringAsFixed(1)}%')),
              ],
            ),
        ],
      ),
    );
  }
  Widget _summaryTable(List<MonthlySummary> summaries) {
    if (summaries.isEmpty) {
      return const Text('No monthly summary data for this selection.');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Month')),
          DataColumn(label: Text('Total costs'), numeric: true),
          DataColumn(label: Text('Total revenue'), numeric: true),
          DataColumn(label: Text('Profit'), numeric: true),
        ],
        rows: [
          for (final s in summaries)
            DataRow(
              cells: [
                DataCell(Text(s.month)),
                DataCell(Text(s.totalCosts.toStringAsFixed(2))),
                DataCell(Text(s.totalRevenue.toStringAsFixed(2))),
                DataCell(Text(s.profit.toStringAsFixed(2))),
              ],
            ),
        ],
      ),
    );
  }
}

String _costDetailsToCsv(List<CostDetail> details) {
  final buffer = StringBuffer()
    ..writeln(
      'Type,Name,Category,Location,Input Cost,Activity Cost,Total Cost',
    );
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
