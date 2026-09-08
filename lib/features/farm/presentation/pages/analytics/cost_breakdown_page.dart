import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/widgets/enterprise_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    final expectedType = selected.kind == EnterpriseKind.season
        ? 'season'
        : 'herd';
    return row.originType == expectedType && row.originId == selected.id;
  }

  @override
  Widget build(BuildContext context) {
    final enterprises = _buildEnterprises(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cost Breakdown by Input Type')),
      body: BlocBuilder<AnalysisBloc, AnalysisState>(
        builder: (context, state) {
          if (state.breakdowns.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.breakdowns.error != null) {
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
                    state.breakdowns.error!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else if (state.breakdowns.data != null) {
            final breakdowns = state.breakdowns.data!;
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
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
