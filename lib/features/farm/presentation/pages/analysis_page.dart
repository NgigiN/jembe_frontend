import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/utils/responsive_utils.dart';
import 'package:farm_tracker/core/widgets/lively_tap.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm_activity/presentation/widgets/farm_activity_card.dart';
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
    context.read<AnalysisBloc>().add(const LoadTotalCostsBySeason());
    context.push(AppRoutePath.totalCosts);
  }

  void _showCostBreakdown(BuildContext context) {
    context.read<AnalysisBloc>().add(const LoadCostBreakdown());
    context.push(AppRoutePath.costBreakdown);
  }

  void _showAnnualSummary(BuildContext context) {
    context.push(AppRoutePath.annualSummary);
  }
}
