import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/core/utils/responsive_utils.dart';
import 'package:farm_tracker/core/widgets/lively_tap.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_year.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/widgets/enterprise_picker.dart';
import 'package:farm_tracker/features/farm_activity/domain/farm_activity_calculator.dart';
import 'package:farm_tracker/features/farm_activity/presentation/farm_activity_level_style.dart';
import 'package:farm_tracker/features/farm_activity/presentation/widgets/farm_activity_card.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farm Analysis')),
      body: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.all(context.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Farm Analytics',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Track your farm performance and costs',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: context.paddingLarge),
              Expanded(
                child: GridView.count(
                  crossAxisCount: context.screenWidth > 600 ? 3 : 2,
                  crossAxisSpacing: context.paddingMedium,
                  mainAxisSpacing: context.paddingMedium,
                  childAspectRatio: 0.85,
                  children: [
                    _buildAnalysisCard(
                      context,
                      'Total Costs by Season',
                      Icons.attach_money,
                      Theme.of(context).colorScheme.primary,
                      () => _showTotalCostsBySeason(context),
                    ),
                    _buildAnalysisCard(
                      context,
                      'Cost Breakdown',
                      Icons.pie_chart,
                      Theme.of(context).colorScheme.secondary,
                      () => _showCostBreakdown(context),
                    ),
                    _buildAnalysisCard(
                      context,
                      'Annual Summary',
                      Icons.calendar_today,
                      Theme.of(context).colorScheme.tertiary,
                      () => _showAnnualSummary(context),
                    ),
                    const FarmActivityCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return LivelyTap(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(context.paddingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.1),
                  color.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: context.fontSize(40), color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to view',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTotalCostsBySeason(BuildContext context) {
    context.read<AnalysisBloc>().add(LoadTotalCostsBySeason());
    context.push(AppRoutePath.totalCosts);
  }

  void _showCostBreakdown(BuildContext context) {
    context.read<AnalysisBloc>().add(LoadCostBreakdown());
    context.push(AppRoutePath.costBreakdown);
  }

  void _showAnnualSummary(BuildContext context) {
    context.push(AppRoutePath.annualSummary);
  }
}

class TotalCostsBySeasonPage extends StatefulWidget {
  const TotalCostsBySeasonPage({super.key});

  @override
  State<TotalCostsBySeasonPage> createState() =>
      _TotalCostsBySeasonPageState();
}

class _TotalCostsBySeasonPageState extends State<TotalCostsBySeasonPage> {
  Enterprise? _selected;

  @override
  void initState() {
    super.initState();
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<HerdBloc>().add(GetHerdsEvent());
  }

  List<Enterprise> _buildEnterprises(BuildContext context) {
    final seasons = context.watch<SeasonBloc>().state.seasons;
    final herds = context.watch<HerdBloc>().state.herds;
    return [
      for (final season in seasons)
        Enterprise(
          id: season.id,
          kind: EnterpriseKind.season,
          name: season.name,
          startDate: season.startDate,
          endDate: season.endDate,
        ),
      for (final herd in herds)
        Enterprise(
          id: herd.id,
          kind: EnterpriseKind.herd,
          name: herd.name,
          startDate: herd.startDate,
          endDate: herd.endDate,
        ),
    ];
  }

  bool _matchesSelected(CostDetail detail) {
    final selected = _selected;
    if (selected == null) {
      return detail.endDate == null || detail.endDate!.isAfter(DateTime.now());
    }
    final expectedType =
        selected.kind == EnterpriseKind.season ? 'plant' : 'animal';
    return detail.type == expectedType && detail.id.toString() == selected.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unified Farm Costs')),
      body: BlocBuilder<AnalysisBloc, AnalysisState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.error != null) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<AnalysisBloc>().add(LoadTotalCostsBySeason());
              },
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.error!,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<AnalysisBloc>().add(
                              LoadTotalCostsBySeason(),
                            );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else if (state.detailedCosts != null) {
            final data = state.detailedCosts!;
            if (data.details.isEmpty) {
              return const Center(child: Text('No cost data available'));
            }

            final visibleDetails = data.details.where(_matchesSelected).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: EnterprisePicker(
                    enterprises: _buildEnterprises(context),
                    selected: _selected,
                    onChanged: (value) => setState(() => _selected = value),
                  ),
                ),
                Expanded(
                  child: visibleDetails.isEmpty
                      ? const Center(
                          child: Text('No cost data for this selection'),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            context.read<AnalysisBloc>().add(
                              LoadTotalCostsBySeason(),
                            );
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: visibleDetails.length,
                            itemBuilder: (context, index) {
                              final detail = visibleDetails[index];
                              return _buildCostDetailItem(context, detail);
                            },
                          ),
                        ),
                ),
              ],
            );
          }
          return const Center(child: Text('No data loaded'));
        },
      ),
    );
  }

  Widget _buildCostDetailItem(BuildContext context, CostDetail detail) {
    final isPlant = detail.type.toLowerCase() == 'plant';
    final itemColor =
        isPlant ? AppColors.plantCategory : AppColors.animalCategory;
    final icon = isPlant ? Icons.grass : Icons.pets;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: itemColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: itemColor),
        ),
        title: Text(
          detail.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${detail.category} • ${detail.location}'),
        trailing: Text(
          'KES ${detail.totalCost.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            fontSize: 16,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildBreakdownRow(context, 'Input Costs', detail.inputCost),
                const SizedBox(height: 8),
                _buildBreakdownRow(
                  context,
                  'Activity Costs',
                  detail.activityCost,
                ),
                const Divider(height: 24),
                _buildBreakdownRow(
                  context,
                  'Total',
                  detail.totalCost,
                  isBold: true,
                ),
                if (detail.endDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Period',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${detail.startDate.toString().split(' ')[0]} to ${detail.endDate.toString().split(' ')[0]}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    double value, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          'KES ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.bold,
            color: isBold ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

class CostBreakdownPage extends StatefulWidget {
  const CostBreakdownPage({super.key});

  @override
  State<CostBreakdownPage> createState() => _CostBreakdownPageState();
}

class _CostBreakdownPageState extends State<CostBreakdownPage> {
  Enterprise? _selected;

  @override
  void initState() {
    super.initState();
    context.read<SeasonBloc>().add(GetSeasonsEvent());
    context.read<HerdBloc>().add(GetHerdsEvent());
  }

  List<Enterprise> _buildEnterprises(BuildContext context) {
    final seasons = context.watch<SeasonBloc>().state.seasons;
    final herds = context.watch<HerdBloc>().state.herds;
    return [
      for (final season in seasons)
        Enterprise(
          id: season.id,
          kind: EnterpriseKind.season,
          name: season.name,
          startDate: season.startDate,
          endDate: season.endDate,
        ),
      for (final herd in herds)
        Enterprise(
          id: herd.id,
          kind: EnterpriseKind.herd,
          name: herd.name,
          startDate: herd.startDate,
          endDate: herd.endDate,
        ),
    ];
  }

  bool _matchesSelected(CostBreakdown row, List<Enterprise> enterprises) {
    final selected = _selected;
    if (selected == null) {
      if (row.originId == null) return true;
      final match = enterprises.where((e) => e.id == row.originId).firstOrNull;
      return match?.isActive ?? true;
    }
    final expectedType =
        selected.kind == EnterpriseKind.season ? 'season' : 'herd';
    return row.originType == expectedType && row.originId == selected.id;
  }

  @override
  Widget build(BuildContext context) {
    final enterprises = _buildEnterprises(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cost Breakdown by Input Type')),
      body: BlocBuilder<AnalysisBloc, AnalysisState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else if (state.breakdowns != null) {
            final breakdowns = state.breakdowns!;
            if (breakdowns.isEmpty) {
              return const Center(child: Text('No data available'));
            }

            final visible = breakdowns
                .where((row) => _matchesSelected(row, enterprises))
                .toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: EnterprisePicker(
                    enterprises: enterprises,
                    selected: _selected,
                    onChanged: (value) => setState(() => _selected = value),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(
                          child: Text('No cost data for this selection'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final breakdown = visible[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  breakdown.category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Origin: ${breakdown.origin}'),
                                    Text('Type: ${breakdown.type}'),
                                    Text(
                                      'Percentage: ${breakdown.percentage.toStringAsFixed(1)}%',
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  'KES ${breakdown.totalCost.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }
          return const Center(child: Text('No data loaded'));
        },
      ),
    );
  }
}

class AnnualSummaryPage extends StatefulWidget {
  const AnnualSummaryPage({super.key});

  @override
  State<AnnualSummaryPage> createState() => _AnnualSummaryPageState();
}

class _AnnualSummaryPageState extends State<AnnualSummaryPage> {
  FarmYear? _farmYear;
  bool _requested = false;

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

          return BlocBuilder<AnalysisBloc, AnalysisState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state.error != null) {
                // Keep the year switcher live even on error - the request
                // that failed is scoped to farmYear, so the user can still
                // page to a different year instead of getting stuck on a
                // dead-end screen.
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<AnalysisBloc>().add(
                      LoadAnnualCostSummary(farmYear.start, farmYear.end),
                    );
                  },
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
                              state.error!,
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                context.read<AnalysisBloc>().add(
                                  LoadAnnualCostSummary(
                                    farmYear.start,
                                    farmYear.end,
                                  ),
                                );
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              } else if (state.summaries != null) {
                // Sort summaries by month string (e.g. "2026-01")
                final sortedSummaries =
                    List<MonthlySummary>.from(state.summaries!)
                      ..sort((a, b) => a.month.compareTo(b.month));

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<AnalysisBloc>().add(
                      LoadAnnualCostSummary(farmYear.start, farmYear.end),
                    );
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildAnnualOverview(
                          context,
                          farmYear,
                          sortedSummaries,
                        ),
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
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final summary = sortedSummaries[index];
                              return _buildMonthlyPerformanceCard(
                                context,
                                summary,
                              );
                            }, childCount: sortedSummaries.length),
                          ),
                        ),
                    ],
                  ),
                );
              }
              return const Center(child: Text('No data loaded'));
            },
          );
        },
      ),
    );
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
    MonthlySummary summary,
  ) {
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
                    color: (isProfit
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
                _buildBreakdownSection(context, summary),
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

  Widget _buildBreakdownSection(BuildContext context, MonthlySummary summary) {
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

class StreakPage extends StatefulWidget {
  const StreakPage({this.now, super.key});

  /// Overridable for tests; defaults to the real current time.
  final DateTime? now;

  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> {
  FarmActivityLevel? _previousLevel;

  @override
  Widget build(BuildContext context) {
    final herds = context.watch<HerdBloc>().state.herds;
    final seasons = context.watch<SeasonBloc>().state.seasons;
    final activities = context.watch<ActivityBloc>().state.activities;
    final inputs = context.watch<InputBloc>().state.inputs;
    final harvests = context.watch<HarvestBloc>().state.harvests;
    final revenues = context.watch<RevenueBloc>().state.revenues;

    const calculator = FarmActivityCalculator();
    final result = calculator.calculate(
      herds: herds,
      seasons: seasons,
      activities: activities,
      inputs: inputs,
      harvests: harvests,
      revenues: revenues,
      now: widget.now,
    );

    final level = result.level;

    if (level == FarmActivityLevel.thriving &&
        _previousLevel != FarmActivityLevel.thriving) {
      SuccessFeedback.thriving();
    }
    _previousLevel = level;

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Activity Streak')),
      body: level == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nothing to track yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildLevelHeader(context, level),
                if (result.weeklyStreak > 0) ...[
                  const SizedBox(height: 16),
                  _buildStreakCallout(context, result.weeklyStreak),
                ],
                const SizedBox(height: 24),
                Text(
                  'Herd & season activity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (final entry in result.breakdown)
                  _buildBreakdownItem(context, entry),
              ],
            ),
    );
  }

  Widget _buildLevelHeader(BuildContext context, FarmActivityLevel level) {
    final color = farmActivityColorFor(context, level);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(farmActivityIconFor(level), color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmActivityLabelFor(level),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(farmActivityExplanationFor(level)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCallout(BuildContext context, int weeklyStreak) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.statusColors.positive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$weeklyStreak-week streak',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  "You've logged something every week for the last "
                  '$weeklyStreak week${weeklyStreak == 1 ? '' : 's'} - keep it up!',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(BuildContext context, EnterpriseFreshness entry) {
    final days = entry.daysSinceLastActivity;
    final isFresh = days != null && days <= 14;
    final String statusText;
    if (days == null) {
      statusText = 'No activity yet';
    } else if (isFresh) {
      statusText = days == 0
          ? 'Active today'
          : 'Active $days day${days == 1 ? '' : 's'} ago';
    } else {
      statusText = 'No activity in $days days';
    }
    final statusColor = days == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (isFresh
            ? context.statusColors.positive
            : context.statusColors.negative);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(entry.isHerd ? Icons.pets : Icons.grass),
        title: Text(entry.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFresh ? Icons.check_circle : Icons.warning_amber,
              color: statusColor,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(statusText, style: TextStyle(color: statusColor)),
          ],
        ),
      ),
    );
  }
}
