import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Wide-layout (`Wrap` of cards) web-console consumer of the existing
/// `DashboardBloc` — there is no mobile dashboard page to mirror; this is a
/// new page purpose-built for the console shell's Dashboard route.
class WebDashboardPage extends StatefulWidget {
  const WebDashboardPage({super.key});

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(GetDashboardEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading || state is DashboardInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is DashboardError) {
            return Center(child: Text(state.message));
          }
          final loaded = state as DashboardLoaded;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                ..._countCards(loaded.counts),
                ..._totalCards(loaded.totals),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _countCards(DashboardCounts counts) => [
    _DashboardCard(label: 'Lands', value: '${counts.lands}'),
    _DashboardCard(label: 'Plants', value: '${counts.plants}'),
    _DashboardCard(label: 'Seasons', value: '${counts.seasons}'),
    _DashboardCard(label: 'Harvests', value: '${counts.harvests}'),
    _DashboardCard(label: 'Animal types', value: '${counts.animalTypes}'),
    _DashboardCard(label: 'Herds', value: '${counts.herds}'),
  ];

  List<Widget> _totalCards(DashboardTotals totals) => [
    _DashboardCard(label: 'Total costs', value: totals.totalCosts.toStringAsFixed(2)),
    _DashboardCard(label: 'Total revenue', value: totals.totalRevenue.toStringAsFixed(2)),
    _DashboardCard(label: 'Profit', value: totals.profit.toStringAsFixed(2)),
  ];
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
