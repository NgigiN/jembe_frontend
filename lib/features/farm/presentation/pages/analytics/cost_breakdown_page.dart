import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/widgets/filters/scope_chips.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/breakdown_grouping.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cost Breakdown by Input Type, scoped by the shared [ScopeChips] selection
/// in [AnalysisBloc]. Rows arrive per (input type × season/herd) and are
/// grouped client-side by input type — one expandable header per type.
class CostBreakdownPage extends StatefulWidget {
  const CostBreakdownPage({super.key});

  @override
  State<CostBreakdownPage> createState() => _CostBreakdownPageState();
}

class _CostBreakdownPageState extends State<CostBreakdownPage> {
  @override
  void initState() {
    super.initState();
    context.read<AnalysisBloc>().add(const LoadCostBreakdown());
    if (OfflineConfig.enabled) {
      context.read<LandBloc>().add(WatchLandsEvent());
      context.read<HerdBloc>().add(WatchHerdsEvent());
    } else {
      context.read<LandBloc>().add(GetLandsEvent());
      context.read<HerdBloc>().add(GetHerdsEvent());
    }
  }

  Future<void> _refresh() async {
    final bloc = context.read<AnalysisBloc>()
      ..add(const LoadCostBreakdown(forceRefresh: true));
    await bloc.stream.firstWhere(
      (s) => !s.breakdowns.isLoading,
      orElse: () => bloc.state,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lands = context.watch<LandBloc>().state.lands;
    final herds = context.watch<HerdBloc>().state.herds;
    return Scaffold(
      appBar: AppBar(title: const Text('Cost Breakdown by Input Type')),
      body: BlocConsumer<AnalysisBloc, AnalysisState>(
        listenWhen: (previous, current) =>
            current.breakdowns.error != null &&
            current.breakdowns.data != null &&
            previous.breakdowns.error != current.breakdowns.error,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(AppSnackBar.error(context, state.breakdowns.error!)),
        builder: (context, state) {
          final slice = state.breakdowns;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ScopeChips(
                  scope: state.scope,
                  lands: lands,
                  herds: herds,
                  onChanged: (scope) => context.read<AnalysisBloc>().add(
                    AnalysisScopeChanged(scope),
                  ),
                ),
              ),
              if (slice.isLoading && slice.data != null)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _body(context, slice)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, AnalysisSlice<List<CostBreakdown>> slice) {
    if (slice.data == null) {
      if (slice.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (slice.error != null) {
        return EntityErrorView(message: slice.error!, onRetry: _refresh);
      }
      return const SizedBox.shrink();
    }
    final groups = groupBreakdowns(slice.data!);
    if (groups.isEmpty) {
      return const EntityEmptyView(
        icon: Icons.pie_chart_outline,
        title: 'No cost data for this selection',
        subtitle: 'Record inputs or activities to see a breakdown.',
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (context, i) => _groupTile(context, groups[i]),
      ),
    );
  }

  Widget _groupTile(BuildContext context, BreakdownGroup group) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          group.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${group.percentage.toStringAsFixed(1)}%'),
        trailing: Text(
          'KES ${group.totalCost.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        children: [
          for (final origin in group.origins)
            ListTile(
              dense: true,
              leading: Icon(
                origin.type == 'plant' ? Icons.grass : Icons.pets,
                color: origin.type == 'plant'
                    ? AppColors.plantCategory
                    : AppColors.animalCategory,
                size: 20,
              ),
              title: Text(origin.origin),
              trailing: Text('KES ${origin.totalCost.toStringAsFixed(2)}'),
            ),
        ],
      ),
    );
  }
}
