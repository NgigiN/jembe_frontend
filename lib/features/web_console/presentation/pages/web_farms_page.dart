import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_card.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_empty.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_identity.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_skeleton.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Farms (DESIGN_SPEC §4, screen 06): every farm you belong to, which one
/// you are looking at, and a panel for starting another.
class WebFarmsPage extends StatefulWidget {
  const WebFarmsPage({required this.remote, super.key});

  final FarmRemoteDataSource remote;

  @override
  State<WebFarmsPage> createState() => _WebFarmsPageState();
}

class _WebFarmsPageState extends State<WebFarmsPage> {
  bool _creating = false;

  Future<void> _create(String name, String location) async {
    setState(() => _creating = true);
    try {
      await widget.remote.createFarm(
        name: sanitizeText(name),
        location: sanitizeText(location),
        fiscalYearStartMonth: 1,
      );
      if (!mounted) return;
      context.read<FarmBloc>().add(RefreshFarms());
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(AppSnackBar.success(context, '$name is ready.'));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error(context, 'Could not create the farm. Try again.'),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FarmBloc>().state;

    return FarmsView(
      farms: state is FarmLoaded ? state.farms : null,
      currentFarmId: state is FarmLoaded ? state.currentFarmId : null,
      errorMessage: state is FarmError ? state.message : null,
      creating: _creating,
      onRetry: () => context.read<FarmBloc>().add(RefreshFarms()),
      onSwitch: (farm) => context.read<FarmBloc>().add(SwitchFarm(farm.id)),
      onManage: () => context.go(WebRoutePath.members),
      onCreate: _create,
    );
  }
}

/// The Farms page's drawing, with no bloc in sight.
class FarmsView extends StatelessWidget {
  const FarmsView({
    required this.farms,
    this.currentFarmId,
    this.errorMessage,
    this.creating = false,
    this.onRetry,
    this.onSwitch,
    this.onManage,
    this.onCreate,
    super.key,
  });

  /// Null while loading.
  final List<Farm>? farms;

  final int? currentFarmId;
  final String? errorMessage;
  final bool creating;
  final VoidCallback? onRetry;
  final void Function(Farm)? onSwitch;

  /// "Manage" on the current farm goes to its Members page — managing a
  /// farm means managing who is on it.
  final VoidCallback? onManage;
  final void Function(String name, String location)? onCreate;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null && farms == null) {
      return ConsoleErrorState(
        farmName: 'your farms',
        subtitle: 'Farms',
        detail: errorMessage!,
        onRetry: onRetry,
      );
    }

    return ConsolePage(
      title: 'Farms',
      subtitle: 'Every farm you belong to, and the one you are looking at',
      rail: ConsoleRail(
        children: [CreateFarmCard(busy: creating, onCreate: onCreate)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConsoleCard(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
            child: _table(context),
          ),
          const SizedBox(height: ConsoleMetrics.gridGap),
          const _SwitchBanner(),
        ],
      ),
    );
  }

  Widget _table(BuildContext context) {
    if (farms == null) return const SkeletonRows(count: 3);
    if (farms!.isEmpty) {
      return const ConsoleEmptyBlock(
        icon: Icons.holiday_village_outlined,
        title: 'No farms yet',
        body: 'Create your first farm to start logging against it.',
      );
    }

    final console = context.console;
    final scheme = Theme.of(context).colorScheme;

    return ConsoleTable(
      columns: const [
        ConsoleColumn('Farm', flex: 5),
        ConsoleColumn('Your role', width: 96, dropBelow: 620),
        ConsoleColumn('County', flex: 3, dropBelow: 760),
        ConsoleColumn('Members', width: 82, alignEnd: true, dropBelow: 540),
        ConsoleColumn('', width: 128, alignEnd: true),
      ],
      rows: [
        for (final farm in farms!)
          ConsoleRow(
            [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: farm.id == currentFarmId
                          ? scheme.primaryContainer
                          : console.container,
                      borderRadius: BorderRadius.circular(
                        ConsoleMetrics.radiusSmallButton,
                      ),
                    ),
                    child: Icon(
                      Icons.agriculture_outlined,
                      size: 17,
                      color: farm.id == currentFarmId
                          ? scheme.onPrimaryContainer
                          : console.onSurface2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      farm.name,
                      style: AppTypography.amount(15).copyWith(
                        color: scheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (farm.id == currentFarmId) ...[
                    const SizedBox(width: 8),
                    const _CurrentTag(),
                  ],
                ],
              ),
              RoleTag(farm.role),
              Text(
                farm.location.isEmpty ? '—' : farm.location,
                style: AppTypography.cell.copyWith(color: console.onSurface2),
                overflow: TextOverflow.ellipsis,
              ),
              Text('${farm.memberCount}', style: AppTypography.cell),
              if (farm.id == currentFarmId)
                ConsoleButton.outlined(label: 'Manage', onPressed: onManage)
              else
                ConsoleButton.tonal(
                  label: 'Switch',
                  icon: Icons.swap_horiz,
                  onPressed: onSwitch == null ? null : () => onSwitch!(farm),
                ),
            ],
            tint: farm.id == currentFarmId ? console.surfaceLow : null,
          ),
      ],
    );
  }
}

class _CurrentTag extends StatelessWidget {
  const _CurrentTag();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTag),
      ),
      child: Text(
        'Current',
        style: AppTypography.tag.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class _SwitchBanner extends StatelessWidget {
  const _SwitchBanner();

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return ConsoleCard(
      color: console.surfaceLow,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: console.onSurface2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Switching farms changes every page in the console. The sidebar '
              'always names the farm you are looking at.',
              style: AppTypography.bodyDense.copyWith(
                color: console.onSurface2,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rail's create panel (DESIGN_SPEC §4, screen 06).
class CreateFarmCard extends StatefulWidget {
  const CreateFarmCard({required this.onCreate, this.busy = false, super.key});

  final void Function(String name, String location)? onCreate;
  final bool busy;

  @override
  State<CreateFarmCard> createState() => _CreateFarmCardState();
}

class _CreateFarmCardState extends State<CreateFarmCard> {
  final _name = TextEditingController();
  final _county = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _county.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      kicker: 'Create a farm',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Field(label: 'Farm name', controller: _name, hint: 'Keringet'),
          const SizedBox(height: 10),
          _Field(label: 'County', controller: _county, hint: 'Nakuru'),
          const SizedBox(height: 12),
          ConsoleButton.filled(
            label: widget.busy ? 'Creating…' : 'Create farm',
            onPressed: widget.busy || widget.onCreate == null
                ? null
                : () {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    widget.onCreate!(name, _county.text.trim());
                    _name.clear();
                    _county.clear();
                  },
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.meta.copyWith(color: context.console.muted),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: AppTypography.bodyDense,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
