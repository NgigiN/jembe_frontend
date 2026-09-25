import 'package:farm_tracker/core/navigation/app_route_path.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Sentence-case label for a role. [FarmRole.wireValue] is the server's
/// lowercase token, which reads like a bug when shown to a user.
String farmRoleLabel(FarmRole role) => switch (role) {
  FarmRole.owner => 'Owner',
  FarmRole.manager => 'Manager',
  FarmRole.worker => 'Worker',
};

/// The farm picker's contents, as a pure view.
///
/// Holds no bloc and performs no navigation so a test can drive it directly.
/// [showFarmSwitcherSheet] supplies the wiring.
class FarmSwitcherSheet extends StatelessWidget {
  const FarmSwitcherSheet({
    required this.farms,
    required this.currentFarmId,
    required this.onSelect,
    required this.onManage,
    this.onCreate,
    super.key,
  });

  final List<Farm> farms;
  final int? currentFarmId;

  /// Called with the chosen farm. Never called for the current farm —
  /// re-selecting it would remount the whole tree for no change.
  final ValueChanged<Farm> onSelect;

  /// Omitted where there is nowhere to create a farm — the console has no
  /// create route, so it shows only [onManage].
  final VoidCallback? onCreate;

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Switch farm', style: theme.textTheme.titleMedium),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: farms.length,
              itemBuilder: (context, index) {
                final farm = farms[index];
                final isCurrent = farm.id == currentFarmId;
                return ListTile(
                  leading: Icon(
                    isCurrent ? Icons.check_circle : Icons.circle_outlined,
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(farm.name),
                  subtitle: Text(farmRoleLabel(farm.role)),
                  selected: isCurrent,
                  onTap: isCurrent ? null : () => onSelect(farm),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              if (onCreate != null)
                Expanded(
                  child: TextButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Create farm'),
                  ),
                ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Manage'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Opens the farm picker and applies the choice.
///
/// Switching dispatches [SwitchFarm], which persists the new id and emits
/// [FarmLoaded]. `FarmScopedBlocs` sees that id change and remounts every
/// farm-scoped bloc, so the page behind the sheet visibly reloads — the
/// point of the whole exercise. The snackbar names the farm so the change is
/// acknowledged even on a screen whose content happens to look similar.
Future<void> showFarmSwitcherSheet(BuildContext context) async {
  final farmBloc = context.read<FarmBloc>();
  final state = farmBloc.state;
  if (state is! FarmLoaded) return;

  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  final chosen = await showModalBottomSheet<Farm>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => FarmSwitcherSheet(
      farms: state.farms,
      currentFarmId: state.currentFarmId,
      onSelect: (farm) => Navigator.of(sheetContext).pop(farm),
      onCreate: () {
        Navigator.of(sheetContext).pop();
        router.push(AppRoutePath.createFarm);
      },
      onManage: () {
        Navigator.of(sheetContext).pop();
        router.push(AppRoutePath.farmManage);
      },
    ),
  );

  if (chosen == null) return;
  farmBloc.add(SwitchFarm(chosen.id));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Switched to ${chosen.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
}
