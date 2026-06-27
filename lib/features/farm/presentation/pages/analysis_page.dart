import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/utils/responsive_utils.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farm Analysis')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
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
                      Colors.blue,
                      () => _showTotalCostsBySeason(context),
                    ),
                    _buildAnalysisCard(
                      context,
                      'Cost Breakdown',
                      Icons.pie_chart,
                      Colors.orange,
                      () => _showCostBreakdown(context),
                    ),
                    _buildAnalysisCard(
                      context,
                      'Annual Summary',
                      Icons.calendar_today,
                      Colors.green,
                      () => _showAnnualSummary(context),
                    ),
                    // _buildAnalysisCard(
                    //   context,
                    //   'Performance Insights',
                    //   Icons.trending_up,
                    //   Colors.purple,
                    //   () => _showPerformanceInsights(context),
                    // ),
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
    return Card(
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
    context.read<AnalysisBloc>().add(LoadAnnualCostSummary());
    context.push(AppRoutePath.annualSummary);
  }

  void _showPerformanceInsights(BuildContext context) {
    // TODO: Implement performance insights
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Performance insights coming soon!')),
    );
  }
}

class TotalCostsBySeasonPage extends StatelessWidget {
  const TotalCostsBySeasonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unified Farm Costs')),
      body: BlocBuilder<AnalysisBloc, AnalysisState>(
        builder: (context, state) {
          if (state is AnalysisLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is AnalysisError) {
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
                          state.message,
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
          } else if (state is TotalCostsBySeasonLoaded) {
            final data = state.detailedCosts;
            if (data.details.isEmpty) {
              return const Center(child: Text('No cost data available'));
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<AnalysisBloc>().add(LoadTotalCostsBySeason());
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildTotalHeader(context, data.totalOverallCost),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final detail = data.details[index];
                        return _buildCostDetailItem(context, detail);
                      }, childCount: data.details.length),
                    ),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('No data loaded'));
        },
      ),
    );
  }

  Widget _buildTotalHeader(BuildContext context, double total) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // child: Column(
      //   children: [
      //     Text(
      //       'Total Overall Farm Cost',
      //       style: Theme.of(context).textTheme.titleMedium?.copyWith(
      //             color: Colors.white.withValues(alpha: 0.9),
      //           ),
      //     ),
      //     const SizedBox(height: 12),
      //     Text(
      //       'KES ${total.toStringAsFixed(2)}',
      //       style: Theme.of(context).textTheme.headlineLarge?.copyWith(
      //             color: Colors.white,
      //             fontWeight: FontWeight.bold,
      //             letterSpacing: 1.2,
      //           ),
      //     ),
      //     const SizedBox(height: 8),
      //     Container(
      //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      //       decoration: BoxDecoration(
      //         color: Colors.white.withValues(alpha: 0.2),
      //         borderRadius: BorderRadius.circular(20),
      //       ),
      //       child: const Text(
      //         'Unified View: Plants & Animals',
      //         style: TextStyle(color: Colors.white, fontSize: 12),
      //       ),
      //     ),
      //   ],
      // ),
    );
  }

  Widget _buildCostDetailItem(BuildContext context, CostDetail detail) {
    final isPlant = detail.type.toLowerCase() == 'plant';
    final Color itemColor = isPlant ? Colors.green : Colors.blue;
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

class CostBreakdownPage extends StatelessWidget {
  const CostBreakdownPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cost Breakdown by Input Type')),
      body: BlocBuilder<AnalysisBloc, AnalysisState>(
        builder: (context, state) {
          if (state is AnalysisLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is AnalysisError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else if (state is CostBreakdownLoaded) {
            if (state.breakdowns.isEmpty) {
              return const Center(child: Text('No data available'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.breakdowns.length,
              itemBuilder: (context, index) {
                final breakdown = state.breakdowns[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      breakdown.category,
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                );
              },
            );
          }
          return const Center(child: Text('No data loaded'));
        },
      ),
    );
  }
}

class AnnualSummaryPage extends StatelessWidget {
  const AnnualSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annual Performance Summary'),
        elevation: 0,
      ),
      body: BlocBuilder<AnalysisBloc, AnalysisState>(
        builder: (context, state) {
          if (state is AnalysisLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is AnalysisError) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<AnalysisBloc>().add(LoadAnnualCostSummary());
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
                          state.message,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<AnalysisBloc>().add(
                              LoadAnnualCostSummary(),
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
          } else if (state is AnnualCostSummaryLoaded) {
            if (state.summaries.isEmpty) {
              return const Center(
                child: Text('No performance data available for this year'),
              );
            }

            // Sort summaries by month string (e.g. "2026-01")
            final sortedSummaries = List<MonthlySummary>.from(state.summaries)
              ..sort((a, b) => a.month.compareTo(b.month));

            return RefreshIndicator(
              onRefresh: () async {
                context.read<AnalysisBloc>().add(LoadAnnualCostSummary());
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildAnnualOverview(context, sortedSummaries),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final summary = sortedSummaries[index];
                        return _buildMonthlyPerformanceCard(context, summary);
                      }, childCount: sortedSummaries.length),
                    ),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('No data loaded'));
        },
      ),
    );
  }

  Widget _buildAnnualOverview(
    BuildContext context,
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
                Colors.greenAccent,
              ),
              _buildOverviewStat(
                'Total Costs',
                totalAnnualCosts,
                Icons.trending_down,
                Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
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
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                    color: (isProfit ? Colors.green : Colors.red).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isProfit ? 'PROFIT' : 'LOSS',
                    style: TextStyle(
                      color: isProfit ? Colors.green : Colors.red,
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
                      Colors.green,
                    ),
                    _buildCompactStat(
                      context,
                      'Costs',
                      summary.totalCosts,
                      Colors.orange,
                    ),
                    _buildCompactStat(
                      context,
                      'Net',
                      summary.profit,
                      isProfit ? Colors.blue : Colors.red,
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
            color: value < 0 ? Colors.red : color,
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
                  _buildSubLabel('Costs'),
                  _buildMiniBreakdownRow(
                    'Plant',
                    summary.breakdown.costs.plant,
                    Colors.green.shade300,
                  ),
                  _buildMiniBreakdownRow(
                    'Animal',
                    summary.breakdown.costs.animal,
                    Colors.blue.shade300,
                  ),
                  _buildMiniBreakdownRow(
                    'Infra',
                    summary.breakdown.costs.infrastructure,
                    Colors.brown.shade300,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubLabel('Revenue'),
                  _buildMiniBreakdownRow(
                    'Plant',
                    summary.breakdown.revenue.plant,
                    Colors.green,
                  ),
                  _buildMiniBreakdownRow(
                    'Animal',
                    summary.breakdown.revenue.animal,
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
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
