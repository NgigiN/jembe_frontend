import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/app_router.dart';
import '../bloc/analysis_bloc.dart';

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Analysis'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              Theme.of(context).colorScheme.surface
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
                    _buildAnalysisCard(
                      context,
                      'Performance Insights',
                      Icons.trending_up,
                      Colors.purple,
                      () => _showPerformanceInsights(context),
                    ),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
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
      appBar: AppBar(
        title: const Text('Total Costs by Season'),
      ),
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
          } else if (state is TotalCostsBySeasonLoaded) {
            if (state.totalCosts.isEmpty) {
              return const Center(child: Text('No data available'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.totalCosts.length,
              itemBuilder: (context, index) {
                final cost = state.totalCosts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      cost.seasonName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text('Plant: ${cost.cropName}'),
                        // Text('Land: ${cost.landName}'),
                        // Text('Farm: ${cost.farmName}'),
                        Text(
                          'Start Date: ${cost.startDate.toString().split(' ')[0]}',
                        ),
                      ],
                    ),
                    trailing: Text(
                      'KES ${cost.totalCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
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

class CostBreakdownPage extends StatelessWidget {
  const CostBreakdownPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cost Breakdown by Input Type'),
      ),
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
                      breakdown.category.isNotEmpty
                          ? breakdown.category
                          : breakdown.inputType,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category: ${breakdown.category.isNotEmpty ? breakdown.category : "N/A"}',
                        ),
                        Text('Type: ${breakdown.inputType}'),
                        Text(
                          'Total Cost: KES ${breakdown.inputCost.toStringAsFixed(2)}',
                        ),
                        Text(
                          'Percentage: ${breakdown.percentage.toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    trailing: Text(
                      'KES ${breakdown.inputCost.toStringAsFixed(2)}',
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
        title: const Text('Annual Cost Summary'),
      ),
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
          } else if (state is AnnualCostSummaryLoaded) {
            if (state.summaries.isEmpty) {
              return const Center(child: Text('No data available'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.summaries.length,
              itemBuilder: (context, index) {
                final summary = state.summaries[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      'Year ${summary.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plant: ${summary.cropName}'),
                        Text('Land: ${summary.landName}'),
                        Text('Farm: ${summary.farmName}'),
                      ],
                    ),
                    trailing: Text(
                      'KES ${summary.totalCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
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
