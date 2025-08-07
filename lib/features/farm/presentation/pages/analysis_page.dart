import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/analysis_bloc.dart';

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Analysis'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Farm Analytics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track your farm performance and costs',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('Tap to view', style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  void _showTotalCostsBySeason(BuildContext context) {
    context.read<AnalysisBloc>().add(LoadTotalCostsBySeason());
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TotalCostsBySeasonPage()),
    );
  }

  void _showCostBreakdown(BuildContext context) {
    context.read<AnalysisBloc>().add(LoadCostBreakdown());
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CostBreakdownPage()),
    );
  }

  void _showAnnualSummary(BuildContext context) {
    context.read<AnalysisBloc>().add(LoadAnnualCostSummary());
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnnualSummaryPage()),
    );
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
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
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
                        Text('Crop: ${cost.cropName}'),
                        Text('Land: ${cost.landName}'),
                        Text('Farm: ${cost.farmName}'),
                        Text(
                          'Start Date: ${cost.startDate.toString().split(' ')[0]}',
                        ),
                      ],
                    ),
                    trailing: Text(
                      '\$${cost.totalCost.toStringAsFixed(2)}',
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
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
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
                      breakdown.inputType,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Season: ${breakdown.seasonName}'),
                        Text('Crop: ${breakdown.cropName}'),
                        Text('Land: ${breakdown.landName}'),
                        Text(
                          'Percentage: ${breakdown.percentage.toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    trailing: Text(
                      '\$${breakdown.inputCost.toStringAsFixed(2)}',
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
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
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
                        Text('Crop: ${summary.cropName}'),
                        Text('Land: ${summary.landName}'),
                        Text('Farm: ${summary.farmName}'),
                      ],
                    ),
                    trailing: Text(
                      '\$${summary.totalCost.toStringAsFixed(2)}',
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
