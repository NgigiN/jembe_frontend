import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/widgets/filters/scope_chips.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_year.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnnualSummaryPage extends StatefulWidget {
  const AnnualSummaryPage({super.key});

  @override
  State<AnnualSummaryPage> createState() => _AnnualSummaryPageState();
}

class _AnnualSummaryPageState extends State<AnnualSummaryPage> {
  FarmYear? _farmYear;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    if (OfflineConfig.enabled) {
      context.read<LandBloc>().add(WatchLandsEvent());
      context.read<HerdBloc>().add(WatchHerdsEvent());
    } else {
      context.read<LandBloc>().add(GetLandsEvent());
      context.read<HerdBloc>().add(GetHerdsEvent());
    }
  }

  void _requestFarmYear(FarmYear farmYear) {
    setState(() => _farmYear = farmYear);
    context.read<AnalysisBloc>().add(
      LoadAnnualCostSummary(farmYear.start, farmYear.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annual Performance Summary'),
        elevation: 0,
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, profileState) {
          if (_farmYear == null) {
            if (profileState is! ProfileLoaded) {
              context.read<ProfileBloc>().add(FetchProfileEvent());
              return const Center(child: CircularProgressIndicator());
            }
            if (!_requested) {
              _requested = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _requestFarmYear(
                  FarmYear.containing(
                    DateTime.now(),
                    profileState.user.fiscalYearStartMonth,
                  ),
                );
              });
            }
            return const Center(child: CircularProgressIndicator());
          }

          final farmYear = _farmYear!;

          return BlocConsumer<AnalysisBloc, AnalysisState>(
            listenWhen: (previous, current) =>
                current.summaries.error != null &&
                current.summaries.data != null &&
                previous.summaries.error != current.summaries.error,
            listener: (context, state) => ScaffoldMessenger.of(
              context,
            ).showSnackBar(AppSnackBar.error(context, state.summaries.error!)),
            builder: (context, state) {
              final slice = state.summaries;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ScopeChips(
                      scope: state.scope,
                      lands: context.watch<LandBloc>().state.lands,
                      herds: context.watch<HerdBloc>().state.herds,
                      onChanged: (scope) => context.read<AnalysisBloc>().add(
                        AnalysisScopeChanged(scope),
                      ),
                    ),
                  ),
                  if (slice.isLoading && slice.data != null)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(child: _content(context, state, farmYear)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _refresh(FarmYear farmYear) async {
    final bloc = context.read<AnalysisBloc>()
      ..add(
        LoadAnnualCostSummary(farmYear.start, farmYear.end, forceRefresh: true),
      );
    await bloc.stream.firstWhere(
      (s) => !s.summaries.isLoading,
      orElse: () => bloc.state,
    );
  }

  Widget _content(
    BuildContext context,
    AnalysisState state,
    FarmYear farmYear,
  ) {
    final slice = state.summaries;
    final showInfra = !state.scope.hasEnterprise;
    if (slice.data == null && slice.isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (slice.data == null && slice.error != null) {
      // Keep the year switcher live even on error - the request
      // that failed is scoped to farmYear, so the user can still
      // page to a different year instead of getting stuck on a
      // dead-end screen.
      return RefreshIndicator(
        onRefresh: () => _refresh(farmYear),
        child: ListView(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: _buildYearSwitcherRow(farmYear),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    slice.error!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refresh(farmYear),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (slice.data != null) {
      // Sort summaries by month string (e.g. "2026-01")
      final sortedSummaries = List<MonthlySummary>.from(slice.data!)
        ..sort((a, b) => a.month.compareTo(b.month));

      return RefreshIndicator(
        onRefresh: () => _refresh(farmYear),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildAnnualOverview(context, farmYear, sortedSummaries),
            ),
            if (sortedSummaries.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No performance data available for this farm year',
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final summary = sortedSummaries[index];
                    return _buildMonthlyPerformanceCard(
                      context,
                      summary,
                      showInfra: showInfra,
                    );
                  }, childCount: sortedSummaries.length),
                ),
              ),
          ],
        ),
      );
    }
    return const Center(child: Text('No data loaded'));
  }

  Widget _buildAnnualOverview(
    BuildContext context,
    FarmYear farmYear,
    List<MonthlySummary> summaries,
  ) {
    double totalAnnualCosts = 0;
    double totalAnnualRevenue = 0;
    for (final s in summaries) {
      totalAnnualCosts += s.totalCosts;
      totalAnnualRevenue += s.totalRevenue;
    }
    final totalAnnualProfit = totalAnnualRevenue - totalAnnualCosts;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildYearSwitcherRow(farmYear),
          const SizedBox(height: 12),
          Text(
            'Annual Net Profit',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'KES ${totalAnnualProfit.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewStat(
                'Total Revenue',
                totalAnnualRevenue,
                Icons.trending_up,
                Colors.white,
              ),
              _buildOverviewStat(
                'Total Costs',
                totalAnnualCosts,
                Icons.trending_down,
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearSwitcherRow(FarmYear farmYear) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => _requestFarmYear(farmYear.previous),
        ),
        Column(
          children: [
            Text(
              'Farm Year ${farmYear.label}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              farmYear.rangeLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white),
          onPressed: farmYear.canGoNext(DateTime.now())
              ? () => _requestFarmYear(farmYear.next)
              : null,
        ),
      ],
    );
  }

  Widget _buildOverviewStat(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          'KES ${value.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyPerformanceCard(
    BuildContext context,
    MonthlySummary summary, {
    required bool showInfra,
  }) {
    final date = DateTime.tryParse('${summary.month}-01') ?? DateTime.now();
    final monthName = _getMonthName(date.month);
    final isProfit = summary.profit >= 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      date.year.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isProfit
                                ? context.statusColors.positive
                                : context.statusColors.negative)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isProfit ? 'PROFIT' : 'LOSS',
                    style: TextStyle(
                      color: isProfit
                          ? context.statusColors.positive
                          : context.statusColors.negative,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCompactStat(
                      context,
                      'Revenue',
                      summary.totalRevenue,
                      context.statusColors.positive,
                    ),
                    _buildCompactStat(
                      context,
                      'Costs',
                      summary.totalCosts,
                      Theme.of(context).colorScheme.onSurface,
                    ),
                    _buildCompactStat(
                      context,
                      'Net',
                      summary.profit,
                      isProfit
                          ? context.statusColors.positive
                          : context.statusColors.negative,
                    ),
                  ],
                ),
                const Divider(height: 32),
                _buildBreakdownSection(context, summary, showInfra: showInfra),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          'KES ${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: value < 0 ? context.statusColors.negative : color,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownSection(
    BuildContext context,
    MonthlySummary summary, {
    required bool showInfra,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detailed Breakdown',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubLabel(context, 'Costs'),
                  _buildMiniBreakdownRow(
                    'Plant',
                    summary.breakdown.costs.plant,
                    AppColors.plantCategory,
                  ),
                  _buildMiniBreakdownRow(
                    'Animal',
                    summary.breakdown.costs.animal,
                    AppColors.animalCategory,
                  ),
                  // Infrastructure has no land/herd link (spec D6): always 0 under a
                  // land or herd scope, so the line is hidden there instead of showing 0.
                  if (showInfra)
                    _buildMiniBreakdownRow(
                      'Infra',
                      summary.breakdown.costs.infrastructure,
                      Theme.of(context).colorScheme.tertiary,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubLabel(context, 'Revenue'),
                  _buildMiniBreakdownRow(
                    'Plant',
                    summary.breakdown.revenue.plant,
                    AppColors.plantCategory,
                  ),
                  _buildMiniBreakdownRow(
                    'Animal',
                    summary.breakdown.revenue.animal,
                    AppColors.animalCategory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMiniBreakdownRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value.toStringAsFixed(0),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
