import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/utils/console_dates.dart';
import 'package:farm_tracker/core/utils/kes.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_event.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_state.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_card.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_controls.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_count_tile.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_empty.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_identity.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_rail.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_skeleton.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_table.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_text.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/feed_entry_look.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/log_on_android_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Dashboard (DESIGN_SPEC §4, screen 02): six count tiles, the season
/// log, and a rail carrying the money position.
///
/// The bloc wiring lives here and the drawing lives in [DashboardView], so
/// the layout can be rendered against the sample data from §8 without a
/// server — see `test/web_console/design_preview_test.dart`.
class WebDashboardPage extends StatefulWidget {
  const WebDashboardPage({super.key});

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> {
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(GetDashboardEvent());
    context.read<FeedBloc>().add(LoadFeed());
    context.read<AnalysisBloc>().add(const LoadCostBreakdown());
  }

  @override
  Widget build(BuildContext context) {
    final farmState = context.watch<FarmBloc>().state;
    final dashboard = context.watch<DashboardBloc>().state;
    final feed = context.watch<FeedBloc>().state;
    final analysis = context.watch<AnalysisBloc>().state;

    return DashboardView(
      farmName: _farmName(farmState) ?? 'Your farm',
      subtitle: _subtitle(farmState),
      counts: dashboard is DashboardLoaded ? dashboard.counts : null,
      totals: dashboard is DashboardLoaded ? dashboard.totals : null,
      entries: feed is FeedLoaded ? feed.entries : null,
      breakdown: analysis.breakdowns.data,
      errorMessage: dashboard is DashboardError ? dashboard.message : null,
      filterIndex: _filter,
      onFilterChanged: (index) => setState(() => _filter = index),
      onRetry: () => context.read<DashboardBloc>().add(GetDashboardEvent()),
    );
  }

  String? _farmName(FarmState state) {
    if (state is! FarmLoaded || state.currentFarmId == null) return null;
    for (final farm in state.farms) {
      if (farm.id == state.currentFarmId) return farm.name;
    }
    return null;
  }

  String _subtitle(FarmState state) {
    final today = formatLongDate(DateTime.now());
    if (state is! FarmLoaded || state.currentFarmId == null) return today;
    for (final farm in state.farms) {
      if (farm.id == state.currentFarmId && farm.location.isNotEmpty) {
        return '${farm.location} · $today';
      }
    }
    return today;
  }
}

/// The Dashboard's drawing, with no bloc in sight.
class DashboardView extends StatelessWidget {
  const DashboardView({
    required this.farmName,
    required this.subtitle,
    required this.counts,
    required this.totals,
    required this.entries,
    required this.breakdown,
    this.errorMessage,
    this.filterIndex = 0,
    this.onFilterChanged,
    this.onRetry,
    super.key,
  });

  /// Null while the dashboard is still loading.
  final DashboardCounts? counts;
  final DashboardTotals? totals;

  /// Null while the feed is still loading.
  final List<FeedEntry>? entries;

  final List<CostBreakdown>? breakdown;

  final String farmName;
  final String subtitle;
  final String? errorMessage;
  final int filterIndex;
  final ValueChanged<int>? onFilterChanged;
  final VoidCallback? onRetry;

  static const _filters = ['All', 'Activities', 'Inputs', 'Harvests', 'Revenue'];
  static const _filterTypes = [
    null,
    'activity',
    'input',
    'harvest',
    'revenue',
  ];

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return ConsoleErrorState(
        farmName: farmName,
        detail: errorMessage!,
        onRetry: onRetry,
      );
    }

    return ConsolePage(
      title: farmName,
      subtitle: subtitle,
      actions: const [
        LogOnAndroidButton(label: 'Log activity'),
        LogOnAndroidButton(label: 'Log input'),
        LogOnAndroidButton(label: 'Log revenue', variant: LogButton.filled),
      ],
      rail: ConsoleRail(
        children: [
          TotalsStack(
            costs: totals?.totalCosts ?? 0,
            revenue: totals?.totalRevenue ?? 0,
            profit: totals?.profit,
            muted: totals == null,
          ),
          _CostBreakdownCard(breakdown: breakdown),
        ],
      ),
      aboveContent: _CountRow(counts: counts),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConsoleCard(
            title: 'Season log',
            titleTrailing: ConsoleChips(
              labels: _filters,
              selectedIndex: filterIndex,
              onSelected: onFilterChanged ?? (_) {},
            ),
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
            child: _SeasonLog(
              entries: entries,
              entityType: _filterTypes[filterIndex],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.counts});

  final DashboardCounts? counts;

  @override
  Widget build(BuildContext context) {
    if (counts == null) {
      return Row(
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            const Expanded(child: Skeleton(height: 74, radius: 14)),
          ],
        ],
      );
    }

    final tiles = <({String label, int count, IconData icon})>[
      (label: 'Lands', count: counts!.lands, icon: Icons.landscape_outlined),
      (label: 'Plants', count: counts!.plants, icon: Icons.local_florist_outlined),
      (label: 'Seasons', count: counts!.seasons, icon: Icons.calendar_month_outlined),
      (label: 'Harvests', count: counts!.harvests, icon: Icons.agriculture_outlined),
      (label: 'Animal types', count: counts!.animalTypes, icon: Icons.pets_outlined),
      (label: 'Herds', count: counts!.herds, icon: Icons.groups_outlined),
    ];

    // No CrossAxisAlignment.stretch here: this Row sits in a scroll view, so
    // its height is unbounded and stretching would ask each tile to be
    // infinitely tall. The six tiles carry the same shape of content, so
    // they come out the same height without being told to.
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: CountTile(
              label: tiles[i].label,
              count: tiles[i].count,
              icon: tiles[i].icon,
            ),
          ),
        ],
      ],
    );
  }
}

class _SeasonLog extends StatelessWidget {
  const _SeasonLog({required this.entries, required this.entityType});

  final List<FeedEntry>? entries;

  /// Null shows everything; otherwise only that `entity_type`.
  final String? entityType;

  /// The mockup's eight rows. The dashboard is a summary — the whole log
  /// is what the Feed page is for.
  static const _rowLimit = 8;

  @override
  Widget build(BuildContext context) {
    if (entries == null) return const SkeletonRows();

    final filtered = entityType == null
        ? entries!
        : entries!.where((e) => e.entityType == entityType).toList();
    final shown = filtered.take(_rowLimit).toList();

    if (shown.isEmpty) {
      return const ConsoleEmptyBlock(
        icon: Icons.notes_outlined,
        title: 'Nothing logged yet',
        body: 'Work logged on the Android app shows up here.',
      );
    }

    return ConsoleTable(
      columns: const [
        ConsoleColumn('Date', width: 84),
        ConsoleColumn('Entry', flex: 4),
        ConsoleColumn('Type', flex: 2),
        ConsoleColumn('Logged by', flex: 2),
        ConsoleColumn('Amount', flex: 2, alignEnd: true),
      ],
      rows: [
        for (final entry in shown) _row(context, entry),
      ],
      footer: Text(
        '${shown.length} of ${filtered.length} '
        '${filtered.length == 1 ? 'entry' : 'entries'}',
      ),
    );
  }

  ConsoleRow _row(BuildContext context, FeedEntry entry) {
    final look = lookOf(entry.entityType);
    final name = loggedByName(entry);

    return ConsoleRow([
      Text(
        formatDayMonth(entry.createdAt.toLocal()),
        style: AppTypography.cell.copyWith(color: context.console.muted),
      ),
      EntryCell(
        icon: look.icon,
        label: entry.summary,
        category: look.category,
      ),
      Text(
        look.type,
        style: AppTypography.cell.copyWith(color: context.console.onSurface2),
      ),
      LoggedByCell(name, avatar: InitialsAvatar(name)),
      // The feed endpoint carries no amount yet, so every row reads as the
      // spec's "n/a" dash rather than a fabricated figure.
      const MoneyText.none(),
    ]);
  }
}

class _CostBreakdownCard extends StatelessWidget {
  const _CostBreakdownCard({required this.breakdown});

  final List<CostBreakdown>? breakdown;

  @override
  Widget build(BuildContext context) {
    if (breakdown == null) {
      return const ConsoleCard(
        kicker: 'Cost breakdown',
        child: Column(
          children: [
            Skeleton(height: 28),
            SizedBox(height: 12),
            Skeleton(height: 28),
            SizedBox(height: 12),
            Skeleton(height: 28),
          ],
        ),
      );
    }

    // Several rows can share a category (one per origin), and the rail has
    // room for a handful of bars — so fold to category totals first and
    // show the biggest.
    final byCategory = <String, double>{};
    for (final row in breakdown!) {
      byCategory[row.category] = (byCategory[row.category] ?? 0) + row.totalCost;
    }
    final total = byCategory.values.fold<double>(0, (sum, v) => sum + v);
    final ranked = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = ranked.take(5).toList();

    if (shown.isEmpty || total == 0) {
      return ConsoleCard(
        kicker: 'Cost breakdown',
        child: Text(
          'No costs logged yet.',
          style: AppTypography.bodyDense.copyWith(color: context.console.muted),
        ),
      );
    }

    return ConsoleCard(
      kicker: 'Cost breakdown',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            ConsoleBarMeter(
              label: shown[i].key,
              fraction: shown[i].value / total,
              trailing: '${(shown[i].value / total * 100).round()}%',
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: AppTypography.bodyDense.copyWith(
                    color: context.console.muted,
                  ),
                ),
              ),
              Text(
                formatKes(total),
                style: AppTypography.amount(15).copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
