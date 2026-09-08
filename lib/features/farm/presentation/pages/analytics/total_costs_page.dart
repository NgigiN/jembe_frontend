import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/widgets/enterprise_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TotalCostsBySeasonPage extends StatefulWidget {
  const TotalCostsBySeasonPage({super.key});

  @override
  State<TotalCostsBySeasonPage> createState() => _TotalCostsBySeasonPageState();
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
    final expectedType = selected.kind == EnterpriseKind.season
        ? 'plant'
        : 'animal';
    return detail.type == expectedType && detail.id.toString() == selected.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unified Farm Costs')),
      body: BlocBuilder<AnalysisBloc, AnalysisState>(
        builder: (context, state) {
          if (state.detailedCosts.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.detailedCosts.error != null) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<AnalysisBloc>().add(
                  const LoadTotalCostsBySeason(),
                );
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
                          state.detailedCosts.error!,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<AnalysisBloc>().add(
                              const LoadTotalCostsBySeason(),
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
          } else if (state.detailedCosts.data != null) {
            final data = state.detailedCosts.data!;
            if (data.details.isEmpty) {
              return const Center(child: Text('No cost data available'));
            }

            final visibleDetails = data.details
                .where(_matchesSelected)
                .toList();

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
                              const LoadTotalCostsBySeason(),
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
