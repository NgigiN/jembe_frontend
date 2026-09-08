import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/widgets/filters/scope_chips.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Unified Farm Costs: one row per season (plant) or herd (animal), scoped
/// by the shared [ScopeChips] selection held in [AnalysisBloc]. Rows are
/// grouped into Active / Completed sections (spec 2026-09-08 D3) so nothing
/// is hidden behind a picker.
class TotalCostsBySeasonPage extends StatefulWidget {
  const TotalCostsBySeasonPage({super.key});

  @override
  State<TotalCostsBySeasonPage> createState() => _TotalCostsBySeasonPageState();
}

class _TotalCostsBySeasonPageState extends State<TotalCostsBySeasonPage> {
  @override
  void initState() {
    super.initState();
    context.read<AnalysisBloc>().add(const LoadTotalCostsBySeason());
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
      ..add(const LoadTotalCostsBySeason(forceRefresh: true));
    // orElse: a closed stream (or one that never emits again) must not
    // throw out of a pull-to-refresh / retry gesture.
    await bloc.stream.firstWhere(
      (s) => !s.detailedCosts.isLoading,
      orElse: () => bloc.state,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lands = context.watch<LandBloc>().state.lands;
    final herds = context.watch<HerdBloc>().state.herds;
    return Scaffold(
      appBar: AppBar(title: const Text('Unified Farm Costs')),
      body: BlocConsumer<AnalysisBloc, AnalysisState>(
        listenWhen: (previous, current) =>
            current.detailedCosts.error != null &&
            current.detailedCosts.data != null &&
            previous.detailedCosts.error != current.detailedCosts.error,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(AppSnackBar.error(context, state.detailedCosts.error!)),
        builder: (context, state) {
          final slice = state.detailedCosts;
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

  Widget _body(BuildContext context, AnalysisSlice<FarmDetailedCost> slice) {
    if (slice.data == null) {
      if (slice.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (slice.error != null) {
        return EntityErrorView(message: slice.error!, onRetry: _refresh);
      }
      return const SizedBox.shrink();
    }
    final details = slice.data!.details;
    if (details.isEmpty) {
      return const EntityEmptyView(
        icon: Icons.attach_money,
        title: 'No cost data for this selection',
        subtitle: 'Costs appear here once inputs or activities are recorded.',
      );
    }
    final now = DateTime.now();
    bool isActive(CostDetail d) => d.endDate == null || d.endDate!.isAfter(now);
    final active = details.where(isActive).toList();
    final completed = details.where((d) => !isActive(d)).toList();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (active.isNotEmpty) ...[
            _header(context, 'Active (${active.length})'),
            _list(active),
          ],
          if (completed.isNotEmpty) ...[
            _header(context, 'Completed (${completed.length})'),
            _list(completed),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  Widget _list(List<CostDetail> rows) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) => _buildCostDetailItem(context, rows[i]),
    ),
  );

  Widget _buildCostDetailItem(BuildContext context, CostDetail detail) {
    final isPlant = detail.type.toLowerCase() == 'plant';
    final itemColor = isPlant
        ? AppColors.plantCategory
        : AppColors.animalCategory;
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
